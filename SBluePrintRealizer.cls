public with sharing class SBluePrintRealizer {
  private SBluePrint sBluePrint;
  Map<String, SObject> aliasToSObject;
  Map<String, String> parentPositionToAlias;
  Integer parentPosition;
  String block;

  public SBluePrintRealizer(
    SBluePrint sBluePrint,
    Map<String, SObject> aliasToSObject,
    Map<String, String> parentPositionToAlias,
    Integer parentPosition,
    String block
  ) {
    this.sBluePrint = sBluePrint;
    this.aliasToSObject = aliasToSObject;
    this.parentPositionToAlias = parentPositionToAlias;
    this.parentPosition = parentPosition;
    this.block = block;
  }

  public Map<String, SObject> realize() {
    System.debug(this.block + 'aliasToSObject at start of realize: ' + aliasToSObject);
    Map<String, SObject> newAliasToSObject = new Map<String, SObject>();
    if (!this.sBluePrint.hasParentBuildPlans()) {
      System.debug(this.block + '親のビルドプランが存在しません');
      for (Integer i = 0; i < this.sBluePrint.getInsertNumber(); i++) {
        SObject sobj = (SObject) this.sBluePrint.getRecordType().newInstance();

        for (String field : this.sBluePrint.getFieldValues().keySet()) {
          SBluePrint.ValueDefinition valueDefinition = this.sBluePrint.getFieldValues().get(field);
          Integer currentSequence = valueDefinition.startAt + (valueDefinition.interval * i);
          Object resolvedValue = this.resolveValue(
            valueDefinition.value,
            currentSequence,
            this.parentPositionToAlias
          );
          sobj.put(field, resolvedValue);
        }

        for (SBluePrint.Dependency dependency : this.sBluePrint.getDependencies()) {
          Integer dependencySequence = dependency.startAt + (dependency.interval * i);
          String resolvedDepencencyAlias = this.resolveValue(
              dependency.alias,
              dependencySequence,
              this.parentPositionToAlias
            )
            .toString();
          System.debug(this.block + 'Resolving alias: ' + dependency.alias + ' -> ' + resolvedDepencencyAlias);
          if (!this.aliasToSObject.containsKey(resolvedDepencencyAlias)) {
            System.debug(this.block + 'Available aliases: ' + String.join(aliasToSObject.keySet(), ', '));
            throw new DmlException('Alias \'' + resolvedDepencencyAlias + '\' not found');
          }

          SObject fromRecord = this.aliasToSObject.get(resolvedDepencencyAlias);
          Object value = fromRecord.get(dependency.fromField);
          sobj.put(dependency.toField, value);
        }

        SBluePrint.AliasDefinition currentAliasDefinition = this.sBluePrint.getAliasDefinition();
        Integer currentAliasSequence = currentAliasDefinition.startAt + (currentAliasDefinition.interval * i);
        String resolvedCurrentAlias = this.resolveValue(
            currentAliasDefinition.alias,
            currentAliasSequence,
            this.parentPositionToAlias
          )
          .toString();
        System.debug(this.block + 'Creating alias: ' + resolvedCurrentAlias + ' -> ' + sobj);
        if (newAliasToSObject.containsKey(resolvedCurrentAlias)) {
          throw new DmlException('Duplicate alias found during realize: ' + resolvedCurrentAlias);
        }
        newAliasToSObject.put(resolvedCurrentAlias, sobj);
      }

      System.debug(this.block + '親のビルドプランがない場合の処理終了');
      return newAliasToSObject;
    }

    System.debug(this.block + '親のビルドプランが存在します');
    SYstem.debug(this.block + 'ビルドプラン数: ' + this.sBluePrint.getParentBuildPlans().size());
    String nextParentPosition = 'P' + parentPosition;

      SBluePrint.ParentBuildPlan parentBuildPlan = this.sBluePrint.getParentBuildPlans()[0];
      String parentAlias = parentBuildPlan.parentAlias.alias;
      System.debug(this.block + 'ビルドプラン: ' + parentBuildPlan);
      System.debug(this.block + '親のビルドプランの作成回数: ' + String.valueOf(parentBuildPlan.insertNumber));
      for (Integer j = 0; j < parentBuildPlan.insertNumber; j++) {
        System.debug(
          this.block +
            '親の生成回数ループのトップ  ' +
            (j + 1) +
            ' / ' +
            parentBuildPlan.insertNumber +
            '   ' +
            parentBuildPlan.parentAlias.alias
        );

        SBluePrint copiedSBluePrint = this.sBluePrint.deepCopy();

        Integer parentSequence = parentBuildPlan.parentAlias.startAt + (parentBuildPlan.parentAlias.interval * j);
        String resolvedParentAlias = this.resolveValue(
            parentBuildPlan.parentAlias.alias,
            parentSequence,
            this.parentPositionToAlias
          )
          .toString();

        Map<String, String> newParentPositionToAlias = this.parentPositionToAlias.clone();

        newParentPositionToAlias.put(nextParentPosition, resolvedParentAlias);
        System.debug(
          this.block + 'nextParentPosition: ' + nextParentPosition + ', parentAlias: ' + resolvedParentAlias
        );

        System.debug(
          this.block +
            'dependenciesの中にビルドプランのAliasが含まれるか確認開始: ' +
            parentBuildPlan.parentAlias.alias
        );

        System.debug(this.block + 'before dependencies: ' + copiedSBluePrint.getDependencies());

        for (SBluePrint.Dependency dependency : copiedSBluePrint.getDependencies()) {
          if (dependency.alias.contains(parentBuildPlan.parentAlias.alias)) {
            System.debug(this.block + '親のビルドプランのAliasが含まれてい流ので置換します: ' + dependency.alias);
            dependency.alias = dependency.alias.replace(
              parentBuildPlan.parentAlias.alias,
              '{' + nextParentPosition + '}'
            );
            System.debug(this.block + '置換後: ' + dependency.alias);
          }
        }
        System.debug(this.block + 'after dependencies: ' + copiedSBluePrint.getDependencies());

        System.debug(
          this.block +
            '自身のエイリアスに親のビルドプランのAliasが含まれていれば置換: ' +
            parentBuildPlan.parentAlias.alias
        );
        String currentAlias = copiedSBluePrint.getAliasDefinition().alias;
        System.debug(this.block + 'before alias: ' + currentAlias);
        if (currentAlias.contains(parentBuildPlan.parentAlias.alias)) {
          System.debug(this.block + '置換します');
          currentAlias = currentAlias.replace(parentBuildPlan.parentAlias.alias, '{' + nextParentPosition + '}');
          copiedSBluePrint.getAliasDefinition().alias = currentAlias;
        }
        System.debug(this.block + 'after alias: ' + currentAlias);
        System.debug(this.block + '親のビルドプランのリストから先頭を削除');
        System.debug(
          this.block + '親のビルドプランの数(削除前): ' + copiedSBluePrint.getParentBuildPlans().size()
        );
        copiedSBluePrint.getParentBuildPlans().remove(0);
        System.debug(
          this.block + '親のビルドプランの数(削除後): ' + copiedSBluePrint.getParentBuildPlans().size()
        );

        System.debug(
          this.block + '親のビルド条件を追加し、親のビルドプランを削除したので生成処理に再帰的に進みます'
        );
        Map<String, SObject> childAliasToSObject = (new SBluePrintRealizer(
            copiedSBluePrint,
            this.aliasToSObject,
            newParentPositionToAlias,
            parentPosition + 1,
            this.block + '______'
          ))
          .realize();
        for (String childAlias : childAliasToSObject.keySet()) {
          if (newAliasToSObject.containsKey(childAlias)) {
            throw new DmlException('Duplicate alias found during realize: ' + childAlias);
          }
          newAliasToSObject.put(childAlias, childAliasToSObject.get(childAlias));
        }

        System.debug(
          this.block +
            '親の生成回数ループのボトム  ' +
            (j + 1) +
            ' / ' +
            parentBuildPlan.insertNumber +
            '   ' +
            parentBuildPlan.parentAlias.alias
        );
      }

    return newAliasToSObject;
  }

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
}
