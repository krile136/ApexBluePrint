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
      /**
      for (SBluePrint.Dependency dependency : sBluePrintWithoutGrandChildren.getDependencies()) {
      1System.debug('今のdependency ' + dependency);
        // {P0} のような形式の場合、数字部分を抜き出すして親のビルドプランから探す
        for (Integer i = 0; i < sBluePrintWithoutGrandChildren.getParentBuildPlans().size(); i++) {
          System.debug(i + '番目の親ビルドプラン: ' + sBluePrintWithoutGrandChildren.getParentBuildPlans()[i]);
          String parentShorthandAlias = '{P' + i + '}';

          SBluePrint.ParentBuildPlan parentBuildPlan = sBluePrintWithoutGrandChildren.getParentBuildPlans()[i];
          String resolvedParentAlias = parentBuildPlan.parentAlias.alias;
          System.debug('resolvedParentAlias: ' + resolvedParentAlias);
          if (dependency.alias.contains(parentShorthandAlias)) {
            dependency.alias = dependency.alias.replace(parentShorthandAlias, resolvedParentAlias);
          }

          String childBluePrintAlias = sBluePrintWithoutGrandChildren.getAlias();
          if (childBluePrintAlias.contains(parentShorthandAlias)) {
            System.debug('子のエイリアスにも親の略称が含まれている: ' + childBluePrintAlias);
            SBluePrint.AliasDefinition childAliasDefinition = sBluePrintWithoutGrandChildren.getAliasDefinition(); 
            String resolvedChildAlias = childAliasDefinition.alias.replace(parentShorthandAlias, resolvedParentAlias);
            sBluePrintWithoutGrandChildren.alias(resolvedChildAlias, childAliasDefinition.startAt, childAliasDefinition.interval);
          }
        }
      }
      **/
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
        System.debug('--------------');
        System.debug('現在のaliasDpthMap: ' + aliasDepthMap);
        System.debug('解決する依存性: ' + pending.dependencyAliases);
        Integer needResolveCount = pending.getDependencyCount();
        System.debug('解決する依存性の数: ' + needResolveCount);
        Integer resolvedCount = 0;
        Integer maxDepth = -1;
        for (String alias : aliasDepthMap.keySet()) {
          if (pending.hasAlias(alias)) {
            System.debug('依存性を一つ解消! alias: ' + alias);
            resolvedCount++;
            System.debug('現在の解決数: ' + resolvedCount);
            Integer depth = aliasDepthMap.get(alias);
            if (depth > maxDepth) {
              maxDepth = depth;
            }
          }
        }
        System.debug('現在のAliasDepthMapで解決できた数: ' + resolvedCount);
        System.debug('解決する依存性の数(再): ' + needResolveCount);

        System.debug('解決できた？: ' + (resolvedCount == needResolveCount));
        if (resolvedCount == needResolveCount) {
          System.debug('依存性の解決成功!');
          System.debug('--------------');
          // all resolved
          SBluePrint resolvedSBluePrint = pending.getSBluePrint();
          Integer currentDepth = maxDepth + 1;
          buildLayers.addSBluePrint(currentDepth, resolvedSBluePrint);
          aliasDepthMap.put(resolvedSBluePrint.getAlias(), currentDepth);
          if (currentDepth > maxLayer) {
            maxLayer = currentDepth;
          }
          for (String alias : resolvedSBluePrint.generateAllAliases()) {
            System.debug('新たに登録するエイリアス: ' + alias + ', depth: ' + currentDepth);
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
    System.debug('全ての依存性解決完了。maxLayer: ' + maxLayer);
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
      System.debug('エイリアス: ' + alias + ' が次の配列にあるか？ ' + this.dependencyAliases);
      System.debug('dependency contain? ' + this.dependencyAliases.contains(alias));
      if (this.dependencyAliases.contains(alias)) {
        this.dependencyAliases.remove(alias);
        return true;
      }

      for (Integer i = 0; i < this.sBluePrint.getParentBuildPlans().size(); i++) {
        System.debug('親のビルドプランのP0 などのチェック開始');
        String parentShorthandAlias = '{P' + i + '}';
        System.debug('parentShorthandAlias: ' + parentShorthandAlias);

        for (String dependencyAlias : this.dependencyAliases) {
          if (dependencyAlias == parentShorthandAlias) {  
            this.dependencyAliases.remove(dependencyAlias);
            return true;
          }
        }
      }

      return false;
    }

    public Integer getDependencyCount() {
      return this.dependencyAliases.size();
    }

    public SBluePrint getSBluePrint() {
      return this.sBluePrint;
    }
  }
}
