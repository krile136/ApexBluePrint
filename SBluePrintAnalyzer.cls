public with sharing class SBluePrintAnalyzer {
  private List<SBluePrint> sBluePrints;
  private AutoAliasCounter autoAliasCounter;

  public SBluePrintAnalyzer(List<SBluePrint> sBluePrints) {
    this.sBluePrints = sBluePrints;
    this.autoAliasCounter = new AutoAliasCounter();
  }

  public SOrchestrator.BuildLayers analyze() {
    AnalysisContext context = this.categorizeBluePrints();
    System.debug('Initial Roots');
    for (SBluePrint root : context.getRoots()) {
      System.debug(root);
    }
    System.debug('Pending BluePrints');
    for (PendingBluePrint pending : context.pendingList) {
      System.debug(pending);
    }
    return this.resolveDependencies(context);
  }

  private AnalysisContext categorizeBluePrints() {
    // SBluePrintをルートとペンディングに分類する
    // 自動的に親子を紐づける
    // {S0}などで親にアクセスできるように親ビルド条件を子に継承させる
    System.debug('----- start categorizeBluePrints -----');
    AnalysisContext context = new AnalysisContext();
    for (SBluePrint sBluePrint : this.sBluePrints) {
      if (!sBluePrint.hasAlias()) {
        String newAlias = this.generateNewAlias(sBluePrint);
        sBluePrint = sBluePrint.alias(newAlias);
      }

      SBluePrint.AliasDefinition parentAliasDefinition = sBluePrint.getAliasDefinition();
      for (SBluePrint child : sBluePrint.getChildren()) {
        child.setParentBuildPlans(sBluePrint);
        System.debug('親ビルドプラン数: ' + child.getParentBuildPlans().size());
        this.categorizeBluePrints(context, sBluePrint, child);
      }

      SBluePrint sBluePrintWithoutChildren = sBluePrint.removeChildren();
      if (sBluePrintWithoutChildren.hasDependencies()) {
        PendingBluePrint pendingBluePrint = new PendingBluePrint(sBluePrintWithoutChildren);
        context.addPendingSBluePrint(pendingBluePrint);
      } else {
        context.addRootSBluePrint(sBluePrintWithoutChildren);
      }
    }
    System.debug('----- end categorizeBluePrints -----');
    return context;
  }

  private void categorizeBluePrints(
    AnalysisContext context,
    SBluePrint parentBluePrint,
    SBluePrint childBluePrint
  ) {
    System.debug(
      'Categorizing child: ' +
        childBluePrint.getRecordTypeName() +
        ' of parent: ' +
        parentBluePrint.getRecordTypeName()
    );
    String toParentField;
    if (childBluePrint.hasParentIdField()) {
      toParentField = childBluePrint.getParentIdField();
    } else {
      SObject parentObject = (SObject) parentBluePrint.getRecordType().newInstance();
      List<Schema.ChildRelationship> childRelationships = parentObject
        .getSObjectType()
        .getDescribe()
        .getChildRelationships();
      String childSObjectName = childBluePrint.getRecordTypeName();
      for (Schema.ChildRelationship childRelationship : childRelationships) {
        if (childRelationship.getChildSObject().getDescribe().getName() == childSObjectName) {
          if (toParentField != null) {
            throw new DmlException('Multiple parent relationship fields found. Please specify parentIdField.');
          }
          toParentField = childRelationship.getField().getDescribe().getName();
        }
      }
      if (toParentField == null) {
        throw new DmlException('No parent relationship field found. Please specify parentIdField.');
      }
    }
    childBluePrint = childBluePrint.use(parentBluePrint.getAlias(), 'Id', toParentField);
    System.debug('childBluePrint after use: ' + childBluePrint);

    if (!childBluePrint.hasAlias()) {
      String newAlias = this.generateNewAlias(childBluePrint);
      newAlias = parentBluePrint.getAlias() + '_' + newAlias;
      childBluePrint = childBluePrint.alias(newAlias);
    }

    SBluePrint.AliasDefinition parentAliasDefinition = childBluePrint.getAliasDefinition();
    for (SBluePrint grandChild : childBluePrint.getChildren()) {
      System.debug('子からみた親のビルドプラン数: ' + childBluePrint.getParentBuildPlans().size());
      grandChild.setParentBuildPlans(childBluePrint);
      System.debug('孫からみたビルドプラン数: ' + grandChild.getParentBuildPlans().size());
      this.categorizeBluePrints(context, childBluePrint, grandChild);
    }

    SBluePrint sBluePrintWithoutGrandChildren = childBluePrint.removeChildren();
    if (sBluePrintWithoutGrandChildren.hasDependencies()) {
      PendingBluePrint pendingBluePrint = new PendingBluePrint(sBluePrintWithoutGrandChildren);
      context.addPendingSBluePrint(pendingBluePrint);
    } else {
      context.addRootSBluePrint(sBluePrintWithoutGrandChildren);
    }
  }

  private SOrchestrator.BuildLayers resolveDependencies(AnalysisContext context) {
    SOrchestrator.BuildLayers buildLayers = new SOrchestrator.BuildLayers();
    Map<String, Integer> aliasDepthMap = new Map<String, Integer>();

    // ビルドレイヤーの初期化
    for (SBluePrint root : context.getRoots()) {
      buildLayers.addSBluePrint(0, root);
      aliasDepthMap.put(root.getAlias(), 0);
      for (String alias : root.generateAllAliases()) {
        aliasDepthMap.put(alias, 0);
      }
    }

    // 依存性解決を行う
    System.debug('依存性解決開始');
    List<PendingBluePrint> pendingBluePrints = context.pendingList;
    System.debug('pending数: ' + pendingBluePrints.size());
    Integer maxLayer = 0;
    while (!pendingBluePrints.isEmpty()) {
      Integer startSize = pendingBluePrints.size();
      for (Integer i = pendingBluePrints.size() - 1; i >= 0; i--) {
        PendingBluePrint pending = pendingBluePrints[i];
        System.debug('Resolving pending: ' + pending);
        Integer resolvedCount = 0;
        Integer maxDepth = -1;
        for (String alias : aliasDepthMap.keySet()) {
          if (pending.hasAlias(alias)) {
            resolvedCount++;
            Integer depth = aliasDepthMap.get(alias);
            if (depth > maxDepth) {
              maxDepth = depth;
            }
          }
        }

        if (resolvedCount == pending.getDependencyCount()) {
          // all resolved
          SBluePrint resolvedSBluePrint = pending.getSBluePrint();
          Integer currentDepth = maxDepth + 1;
          buildLayers.addSBluePrint(currentDepth, resolvedSBluePrint);
          aliasDepthMap.put(resolvedSBluePrint.getAlias(), currentDepth);
          if (currentDepth > maxLayer) {
            maxLayer = currentDepth;
          }
          for (String alias : resolvedSBluePrint.generateAllAliases()) {
            aliasDepthMap.put(alias, currentDepth);
          }

          pendingBluePrints.remove(i);
        }
      }
      Integer endSize = pendingBluePrints.size();
      System.debug('startSize: ' + startSize + ', endSize: ' + endSize);
      if (startSize == endSize) {
        throw new DmlException('Circular reference detected among aliases: ' + pendingBluePrints);
      }
    }
    System.debug('依存性解決完了。maxLayer: ' + maxLayer);
    return buildLayers;
  }

  private String generateNewAlias(SBluePrint sBluePrint) {
    String newAlias = String.format(
      '__{0}_{1}',
      new List<String>{ sBluePrint.getRecordTypeName(), autoAliasCounter.getValue().toString() }
    );
    newAlias += '_{#}__';
    autoAliasCounter.increment();
    return newAlias;
  }

  private class AnalysisContext {
    private SOrchestrator.BuildLayers buildLayers;
    private List<PendingBluePrint> pendingList;

    public AnalysisContext() {
      this.buildLayers = new SOrchestrator.BuildLayers();
      this.pendingList = new List<PendingBluePrint>();
    }

    public void addRootSBluePrint(SBluePrint sBluePrint) {
      this.buildLayers.addSBluePrint(0, sBluePrint);
    }

    public void addPendingSBluePrint(PendingBluePrint pendingBluePrint) {
      this.pendingList.add(pendingBluePrint);
    }

    public List<SBluePrint> getRoots() {
      return this.buildLayers.getSBluePrintsByLayer(0);
    }

    public Boolean hasPending() {
      return !this.pendingList.isEmpty();
    }

    public void mergeContext(AnalysisContext otherContext) {
      List<SBluePrint> otherRoots = otherContext.getRoots();
      for (SBluePrint root : otherRoots) {
        this.buildLayers.addRoot(root);
      }
      this.pendingList.addAll(otherContext.pendingList);
    }
  }

  public class AutoAliasCounter {
    private Integer value = 0;

    public Integer getValue() {
      return this.value;
    }

    public void increment() {
      this.value++;
    }
  }

  public class PendingBluePrint {
    private SBluePrint sBluePrint;
    private Set<String> dependencyAliases;

    public PendingBluePrint(SBluePrint sBluePrint) {
      this.sBluePrint = sBluePrint;
      this.dependencyAliases = sBluePrint.getDependencyAliases();
    }

    public Boolean hasAlias(String alias) {
      System.debug('Checking alias: ' + alias + ' in ' + this.dependencyAliases);
      return this.dependencyAliases.contains(alias);
    }

    public Integer getDependencyCount() {
      return this.dependencyAliases.size();
    }

    public SBluePrint getSBluePrint() {
      return this.sBluePrint;
    }
  }
}
