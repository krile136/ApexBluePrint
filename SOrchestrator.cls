public with sharing class SOrchestrator {
  @TestVisible
  private List<SBluePrint> sBluePrints;
  private Map<String, SObject> aliasToSObject = new Map<String, SObject>();
  private IDmlOperator dmlOperator;

  private SOrchestrator() {
    this.sBluePrints = new List<SBluePrint>();
    this.dmlOperator = new DmlOperator();
  }
  
  private SOrchestrator(IDmlOperator dmlOperator) {
    System.debug('Using custom DmlOperator: ' + dmlOperator);
    this.sBluePrints = new List<SBluePrint>();
    this.dmlOperator = dmlOperator;
  }

  public static SOrchestrator start() {
    return new SOrchestrator();
  }

  public static SOrchestrator start(IDmlOperator dmlOperator) {
    return new SOrchestrator(dmlOperator);
  }

  public SOrchestrator add(SBluePrint sBluePrint) {
    System.debug(this.dmlOperator);
    if (sBluePrint == null) {
      throw new DmlException('sBluePrint must not be null');
    }
    SOrchestrator newSOrchestrator = this.deepCopy();
    newSOrchestrator.sBluePrints.add(sBluePrint);

    return newSOrchestrator;
  }

  public void create() {
    System.debug('dmlOperator at start of create: ' + this.dmlOperator);
    BuildLayers buildLayers = (new SBluePrintAnalyzer(this.sBluePrints)).analyze();
    buildLayers.realizeAll(this.aliasToSObject, buildLayers.getMapDepth(), this.dmlOperator);
  }

  public SObject getByAlias(String alias) {
    if (this.aliasToSObject.containsKey(alias)) {
      return this.aliasToSObject.get(alias);
    }
    return null;
  }

  private SOrchestrator deepCopy() {
    SOrchestrator newSOrchestrator = new SOrchestrator();
    newSOrchestrator.sBluePrints = this.sBluePrints.clone();
    this.aliasToSObject = this.aliasToSObject.clone();
    newSOrchestrator.dmlOperator = this.dmlOperator;

    return newSOrchestrator;
  }

  public class BuildLayer {
    private List<SBluePrint> sBluePrints = new List<SBluePrint>();

    public void addSBluePrint(SBluePrint sBluePrint) {
      this.sBluePrints.add(sBluePrint);
    }

    public List<SBluePrint> getSBluePrints() {
      return this.sBluePrints;
    }

    public void realizeLayer(Map<String, SObject> aliasToSObject, IDmlOperator dmlOperator) {
      System.debug('aliasToSObject before layer insert: ' + aliasToSObject);
      Map<String, SObject> layerAliasToSObject = new Map<String, SObject>();
      System.debug('sbluePrint count: ' + this.sBluePrints.size());
      for (SBluePrint sBluePrint : this.sBluePrints) {
        Map<String, SObject> newAliasToSObject = new SBluePrintRealizer(sBluePrint, aliasToSObject, new Map<String, String>(), 0, '').realize();
        System.debug('bluePrintのrealize完了');
        for (String alias : newAliasToSObject.keySet()) {
          System.debug('Inserting alias: ' + alias + ' -> ' + newAliasToSObject.get(alias));
          if (layerAliasToSObject.containsKey(alias)) {
            throw new DmlException('Duplicate alias found during layer prepare: ' + alias);
          }
          layerAliasToSObject.put(alias, newAliasToSObject.get(alias));
        }
      }
      System.debug('dmlOperator before layer insert: ' + dmlOperator);
      dmlOperator.doInsert(layerAliasToSObject.values());

      for (String alias : layerAliasToSObject.keySet()) {
        SObject sobj = layerAliasToSObject.get(alias);
        if (aliasToSObject.containsKey(alias)) {
          throw new DmlException('Duplicate alias found during layer insert: ' + alias);
        }
        aliasToSObject.put(alias, sobj);
      }
      System.debug('aliasToSObject after layer insert: ' + aliasToSObject);
    }
  }

  public class BuildLayers {
    private Map<String, BuildLayer> layers = new Map<String, BuildLayer>();

    public Integer getMapDepth() {
      return this.layers.keySet().size() - 1;
    }

    public void addSBluePrint(Integer layerNumber, SBluePrint sBluePrint) {
      String layerKey = String.valueOf(layerNumber);
      if (!this.layers.containsKey(layerKey)) {
        this.layers.put(layerKey, new BuildLayer());
      }
      this.layers.get(layerKey).addSBluePrint(sBluePrint);
    }

    public void addRoot(SBluePrint sBluePrint) {
      this.addSBluePrint(0, sBluePrint);
    }

    public List<SBluePrint> getSBluePrintsByLayer(Integer layerNumber) {
      String layerKey = String.valueOf(layerNumber);
      if (!this.layers.containsKey(layerKey)) {
        return new List<SBluePrint>();
      }
      return this.layers.get(layerKey).getSBluePrints();
    }

    public List<SBluePrint> getRoots() {
      return this.getSBluePrintsByLayer(0);
    }

    public void realizeAll(Map<String, SObject> aliasToSObject, Integer maxLayer, IDmlOperator dmlOperator) {
      System.debug('maxLayer: ' + maxLayer);
      for (String key : this.layers.keySet()) {
        System.debug('Available layers: ' + key);
        System.debug('  sBluePrint count: ' + this.layers.get(key).getSBluePrints().size());
      }
      for (Integer i = 0; i <= maxLayer; i++) {
        System.debug('---------start insert layer -------------------');
        System.debug('dml operator: ' + dmlOperator);
        String layerKey = String.valueOf(i);
        System.debug('Inserting layer: ' + layerKey);
        this.layers.get(layerKey).realizeLayer(aliasToSObject, dmlOperator);
        System.debug('---------finish insert layer-----------------------');
      }
    }
  }

  public class PendingBluePrint {
    private Set<String> useAliaseNames = new Set<String>();
    private SBluePrint sBluePrint;

    public PendingBluePrint(Set<String> useAliaseNames, SBluePrint sBluePrint) {
      this.useAliaseNames = useAliasenames;
      this.sBluePrint = sBluePrint;
    }

    public Boolean hasAlias(String alias) {
      System.debug('Checking alias: ' + alias + ' in ' + this.useAliaseNames);
      return this.useAliaseNames.contains(alias);
    }

    public Integer getUseAliasCount() {
      return this.useAliaseNames.size();
    }

    public SBluePrint getSBluePrint() {
      return this.sBluePrint;
    }
  }
}
