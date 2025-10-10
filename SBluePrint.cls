public with sharing class SBluePrint {
  @TestVisible
  private System.Type recordType;
  @TestVisible
  private AliasDefinition aliasDefinition;
  @TestVisible
  private String parentIdField;
  @TestVisible
  private Integer insertNumber = 1;
  @TestVisible
  private Map<String, ValueDefinition> fieldValues = new Map<String, ValueDefinition>();
  @TestVisible
  private List<Dependency> dependencies = new List<Dependency>();
  @TestVisible
  private List<SBluePrint> children = new List<SBluePrint>();
  private List<ParentBuildPlan> parentBuildPlans = new List<ParentBuildPlan>();

  private SBluePrint(System.Type recordType) {
    this.recordType = recordType;
  }

  public static SBluePrint of(System.Type recordType) {
    guard(recordType);
    return new SBluePrint(recordType);
  }

  private static void guard(System.Type recordType) {
    if (recordType == null) {
      throw new DmlException('RecordType must not be null');
    }

    if (!(recordType.newInstance() instanceof SObject)) {
      throw new DmlException('RecordType must be SObject type');
    }
  }

  public SBluePrint set(String fieldName, Object value) {
    return this.set(fieldName, value, 1, 1);
  }

  public SBluePrint set(String fieldName, Object value, Integer startAt) {
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    return this.set(fieldName, value, startAt, 1);
  }

  public SBluePrint set(String fieldName, Object value, Integer startAt, Integer interval) {
    if (interval <= 0) {
      throw new DmlException('Interval must be greater than 0');
    }
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    ValueDefinition valueDefinition = new ValueDefinition(value, startAt, interval);
    newSBluePrint.fieldValues.put(fieldName, valueDefinition);
    return newSBluePrint;
  }

  public SBluePrint use(String alias, String fromField, String toField) {
    SBluePrint newSBluePrint = this.deepCopy();
    Dependency dependency = new Dependency(alias, fromField, toField, 1, 1);
    newSBluePrint.dependencies.add(dependency);
    return newSBluePrint;
  }

  public SBluePrint use(String alias, String fromField, String toField, Integer startAt) {
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    Dependency dependency = new Dependency(alias, fromField, toField, startAt, 1);
    newSBluePrint.dependencies.add(dependency);
    return newSBluePrint;
  }

  public SBluePrint use(String alias, String fromField, String toField, Integer startAt, Integer interval) {
    if (interval <= 0) {
      throw new DmlException('Interval must be greater than 0');
    }
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    Dependency dependency = new Dependency(alias, fromField, toField, startAt, interval);
    newSBluePrint.dependencies.add(dependency);
    return newSBluePrint;
  }

  public SBluePrint template(Map<String, Object> template) {
    SBluePrint newSBluePrint = this.deepCopy();
    for (String key : template.keySet()) {
      if (!newSBluePrint.fieldValues.containsKey(key)) {
        ValueDefinition valueDefinition = new ValueDefinition(template.get(key), 1, 1);
        newSBluePrint.fieldValues.put(key, valueDefinition);
      }
    }
    return newSBluePrint;
  }

  public SBluePrint alias(String alias) {
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.aliasDefinition = new AliasDefinition(alias, 1, 1);
    return newSBluePrint;
  }

  public SBluePrint alias(String alias, Integer startAt) {
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.aliasDefinition = new AliasDefinition(alias, startAt, 1);
    return newSBluePrint;
  }

  public SBluePrint alias(String alias, Integer startAt, Integer interval) {
    if (interval <= 0) {
      throw new DmlException('Interval must be greater than 0');
    }
    if (startAt <= 0) {
      throw new DmlException('startAt must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.aliasDefinition = new AliasDefinition(alias, startAt, interval);
    return newSBluePrint;
  }

  public void setParentBuildPlans(SBluePrint parentBluePrint) {
    this.parentBuildPlans = parentBluePrint.parentBuildPlans.clone();
    System.debug('現在のビルドプラン数: ' + this.parentBuildPlans.size());
    ParentBuildPlan parentBuildPlan  = parentBluePrint.generateParentBuildPlan();
    System.debug('追加するビルドプラン: ' + parentBuildPlan);
    this.parentBuildPlans.add(parentBuildPlan);
    System.debug('追加後のビルドプラン数: ' + this.parentBuildPlans.size());
  }

  private ParentBuildPlan generateParentBuildPlan() {
    return new ParentBuildPlan(
      this.aliasDefinition,
      this.insertNumber
    );
  }

  public String getAlias() {
    if (this.aliasDefinition == null) {
      throw new DmlException('Alias is not set');
    }
    return this.aliasDefinition.alias;
  }

  public AliasDefinition getAliasDefinition() {
    return this.aliasDefinition;
  }


  public SBluePrint times(Integer times) {
    if (times <= 0) {
      throw new DmlException('Times must be greater than 0');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.insertNumber = times;
    return newSBluePrint;
  }

  public SBluePrint parentIdField(String field) {
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.parentIdField = field;
    return newSBluePrint;
  }

  public SBluePrint withChildren(SBluePrint child) {
    if (child == null) {
      throw new DmlException('Child record must not be null');
    }
    SBluePrint newSBluePrint = this.deepCopy();
    newSBluePrint.children.add(child);
    return newSBluePrint;
  }

  public Boolean hasAlias() {
    return this.aliasDefinition != null;
  }

  public Boolean hasParentBuildPlans() {
    return !this.parentBuildPlans.isEmpty();
  }

  public Integer getInsertNumber() {
    return this.insertNumber;
  }

  public List<ParentBuildPlan> getParentBuildPlans() {
    return this.parentBuildPlans;
  }

  public Map<String, ValueDefinition> getFieldValues() {
    return this.fieldValues;
  }

  public System.Type getRecordType() {
    return this.recordType;
  }

  public String getRecordTypeName() {
    return this.recordType.getName();
  }

  public SBluePrint removeChildren() {
    SBluePrint copy = this.deepCopy();
    copy.children = null;
    return copy;
  }

  public Boolean hasDependencies() {
    return !this.dependencies.isEmpty();
  }

  public Set<String> getDependencyAliases() {
    Set<String> aliases = new Set<String>();
    for (Dependency dependency : this.dependencies) {
      aliases.add(dependency.alias);
    }
    return aliases;
  }

  public List<Dependency> getDependencies() {
    return this.dependencies;
  }

  public List<SBluePrint> getChildren() {
    return this.children;
  }

  public Boolean hasParentIdField() {
    return String.isNotBlank(this.parentIdField);
  }

  public String getParentIdField() {
    return this.parentIdField;
  }
  
  public Map<String, SObject> realize(
    Map<String, SObject> aliasToSObject,
    Map<String, String> parentPositionToAlias
  ) {
    System.debug('aliasToSObject at start of realize: ' + aliasToSObject);
    Map<String, SObject> newAliasToSObject = new Map<String, SObject>();
    System.debug('親のビルドプランを持つ？ ' + !this.parentBuildPlans.isEmpty());
    if (this.parentBuildPlans.isEmpty()) {
      for (Integer i = 0; i < this.insertNumber; i++) {
        SObject sobj = (SObject) this.recordType.newInstance();

        for (String field : this.fieldValues.keySet()) {
          ValueDefinition valueDefinition = this.fieldValues.get(field);
          Integer currentSequence = valueDefinition.startAt + (valueDefinition.interval * i);
          Object resolvedValue = this.resolveValue(valueDefinition.value, currentSequence, parentPositionToAlias);
          sobj.put(field, resolvedValue);
        }

        for (Dependency dependency : this.dependencies) {
          Integer dependencySequence = dependency.startAt + (dependency.interval * i);
          String alias = this.resolveValue(dependency.alias, dependencySequence, parentPositionToAlias).toString();
          System.debug('Resolving alias: ' + dependency.alias + ' -> ' + alias);
          if (!aliasToSObject.containsKey(alias)) {
            System.debug('Available aliases: ' + String.join(aliasToSObject.keySet(), ', '));
            throw new DmlException('Alias \'' + alias + '\' not found');
          }

          SObject fromRecord = aliasToSObject.get(alias);
          Object value = fromRecord.get(dependency.fromField);
          sobj.put(dependency.toField, value);
        }

        String aliasString = this.aliasDefinition.alias;
        Integer aliasSequence = this.aliasDefinition.startAt + (this.aliasDefinition.interval * i);
        String currentAlias = this.resolveValue(aliasString, aliasSequence, parentPositionToAlias).toString();
        System.debug('Creating alias: ' + currentAlias + ' -> ' + sobj);
        if (newAliasToSObject.containsKey(currentAlias)) {
          throw new DmlException('Duplicate alias found during realize: ' + currentAlias);
        }
        newAliasToSObject.put(currentAlias, sobj);
      }
    } else {
      System.debug('親のビルドプランが存在します');
      List<ParentBuildPlan> clonedParentBuildPlans = this.parentBuildPlans.clone();
      for (Integer i = 0; i < clonedParentBuildPlans.size(); i++) {
        ParentBuildPlan parentBuildPlan = clonedParentBUildPlans[i];
        System.debug('ビルドプラン: ' + parentBuildPlan);
        String nextParentPosition = 'P' + String.valueOf(i);
        for (Integer j = 0; j < parentBuildPlan.insertNumber; j++) {
          System.debug('**********');
          Integer parentSequence =
            parentBuildPlan.parentAlias.startAt + (parentBuildPlan.parentAlias.interval * j);
          String parentAlias = this.resolveValue(
              parentBuildPlan.parentAlias.alias,
              parentSequence,
              parentPositionToAlias
            )
            .toString();
          parentPositionToAlias.put(nextParentPosition, parentAlias);
          System.debug('nextParentPosition: ' + nextParentPosition + ', parentAlias: ' + parentAlias);

          SBluePrint sBluePrintAfterRemoveParent = this.deepCopy();
          System.debug('dependenciesの中にビルドプランのAliasが含まれるか確認開始');
          System.debug('before dependencies: ' + sBluePrintAfterRemoveParent.dependencies);
          for (Dependency dependency : sBluePrintAfterRemoveParent.dependencies) {
            if (dependency.alias == parentBuildPlan.parentAlias.alias) {
              System.debug('親のビルドプランのAliasが含まれています: ' + dependency.alias);
              System.debug(
                'dependencyのaliasをpositionに置き換えます: ' + dependency.alias + ' -> {' + nextParentPosition + '}'
              );
              dependency.alias = '{' + nextParentPosition + '}';
            }
          }
          System.debug('after dependencies: ' + sBluePrintAfterRemoveParent.dependencies);

          System.debug('自身のエイリアスに親のビルドプランのAliasが含まれていれば置換');
          String aliasString = sBluePrintAfterRemoveParent.aliasDefinition.alias;
          System.debug('before alias: ' + aliasString);
          if (aliasString.contains(parentBuildPlan.parentAlias.alias)) {
            System.debug('置換します');
            aliasString = aliasString.replace(parentBuildPlan.parentAlias.alias, '{' + nextParentPosition + '}');
            sBluePrintAfterRemoveParent.aliasDefinition.overrideAlias(aliasString);
          }
          System.debug('after alias: ' + aliasString);

          sBluePrintAfterRemoveParent.parentBuildPlans.remove(0);
          Map<String, SObject> childAliasToSObject = sBluePrintAfterRemoveParent.realize(
            aliasToSObject,
            parentPositionToAlias
          );
          for (String alias : childAliasToSObject.keySet()) {
            if (newAliasToSObject.containsKey(alias)) {
              throw new DmlException('Duplicate alias found during realize with parent: ' + alias);
            }
            newAliasToSObject.put(alias, childAliasToSObject.get(alias));
          }
        }
      }
    }

    return newAliasToSObject;
  }

  public List<String> generateAllAliases() {
    List<String> aliases = new List<String>();
    String alias = this.aliasDefinition.alias;
    if (alias != null && (alias.contains('{#}') || alias.contains('{A}') || alias.contains('{a}'))) {
      for (Integer i = 0; i < this.insertNumber; i++) {
        Integer aliasSequence = this.aliasDefinition.startAt + (this.aliasDefinition.interval * i);
        String currentAlias = this.resolveValue(alias, aliasSequence, null).toString();
        aliases.add(currentAlias);
      }
    }
    return aliases;
  }

  public SBluePrint deepCopy() {
    SBluePrint copy = SBluePrint.of(this.recordType);
    copy.aliasDefinition = this.aliasDefinition;
    copy.parentIdField = this.parentIdField;
    copy.insertNumber = this.insertNumber;
    copy.fieldValues = this.fieldValues == null ? new Map<String, ValueDefinition>() : this.fieldValues.clone();
    copy.dependencies = this.dependencies == null ? new List<Dependency>() : this.dependencies.clone();
    copy.children = this.children == null ? new List<SBluePrint>() : this.children.clone();
    copy.parentBuildPlans = this.parentBuildPlans == null
      ? new List<ParentBuildPlan>()
      : this.parentBuildPlans.clone();

    return copy;
  }

  /**
   * Resolves a template value by replacing placeholders with the current sequence number.
   * Supported placeholders:
   * - '{#}': Replaced with the current sequence number.
   * - '{A}': Replaced with the current sequence number converted to an uppercase alphabetic representation.
   * - '{a}': Replaced with the current sequence number converted to a lowercase alphabetic representation.
   * If the template value is not a string, it is returned as-is.
   *
   * @param templateValue The template value containing placeholders.
   * @param sequence The current sequence number to replace placeholders.
   * @return The resolved value with placeholders replaced.
   */
  private Object resolveValue(Object templateValue, Integer sequence, Map<String, String> parentPositionToAlias) {
    if (!(templateValue instanceof String)) {
      return templateValue;
    }
    parentPositionToAlias = parentPositionToAlias == null ? new Map<String, String>() : parentPositionToAlias;

    String value = (String) templateValue;

    if (value == '{#}') {
      return sequence;
    }

    String resolvedString = value.replace('{#}', String.valueOf(sequence))
      .replace('{A}', this.convertNumberToAlphabet(sequence, true))
      .replace('{a}', this.convertNumberToAlphabet(sequence, false));

    for (String key : parentPositionToAlias.keySet()) {
      String placeholder = '{' + key + '}';
      if (resolvedString.contains(placeholder)) {
        resolvedString = resolvedString.replace(placeholder, parentPositionToAlias.get(key));
      }
    }

    return resolvedString;
  }

  /**
   * Converts a positive integer to its corresponding alphabetic representation.
   * For example, 1 -> 'A', 26 -> 'Z', 27 -> 'AA', 52 -> 'AZ', 53 -> 'BA', etc.
   *
   * @param num The positive integer to convert.
   * @param isUpperCase If true, returns uppercase letters; if false, returns lowercase letters.
   * @return The alphabetic representation of the number.
   */
  private String convertNumberToAlphabet(Integer num, Boolean isUpperCase) {
    if (num == null || num <= 0) {
      return '';
    }

    final Integer BASE_CHAR_CODE = isUpperCase ? 65 : 97;
    final Integer BASE = 26;
    String result = '';

    Integer current = num;
    while (current > 0) {
      Integer remainder = Math.mod(current - 1, BASE);

      Integer charCode = BASE_CHAR_CODE + remainder;
      result = String.fromCharArray(new List<Integer>{ charCode }) + result;

      current = (current - remainder) / BASE;
    }
    return result;
  }

  @TestVisible
  public class ValueDefinition {
    public Object value;
    public Integer startAt;
    public Integer interval;

    public ValueDefinition(Object value, Integer startAt, Integer interval) {
      this.value = value;
      this.startAt = startAt;
      this.interval = interval;
    }
  }

  @TestVisible
  public class AliasDefinition {
    public String alias;
    public Integer startAt;
    public Integer interval;

    public AliasDefinition(String alias, Integer startAt, Integer interval) {
      this.alias = alias;
      this.startAt = startAt;
      this.interval = interval;
    }

    public void overrideAlias(String alias) {
      this.alias = alias;
    }
  }

  @TestVisible
  public class Dependency {
    public String alias;
    public String fromField;
    public String toField;
    public Integer startAt;
    public Integer interval;

    public Dependency(String alias, String fromField, String toField, Integer startAt, Integer interval) {
      this.alias = alias;
      this.fromField = fromField;
      this.toField = toField;
      this.startAt = startAt;
      this.interval = interval;
    }
  }

  @TestVisible
  public class ParentBuildPlan {
    public AliasDefinition parentAlias;
    public Integer insertNumber;

    public ParentBuildPlan(AliasDefinition parentAlias, Integer insertNumber) {
      this.parentAlias = parentAlias;
      this.insertNumber = insertNumber;
    }
  }
}
