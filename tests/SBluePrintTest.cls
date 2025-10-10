@isTest
public with sharing class SBluePrintTest {
  @isTest
  static void testOf_WhenAddRecordType_ThenCreateSBluePrint() {
    // Arrange
    System.Type recordType = Account.class;

    // Act
    SBluePrint sBluePrint = SBluePrint.of(recordType);
    // Assert
    Assert.areEqual(recordType, sBluePrint.recordType, 'RecordType should be set');
  }

  @isTest
  static void testOf_WhenRecordTypeIsNull_ThenThrowException() {
    // Arrange
    System.Type recordType = null;

    // Act & Assert
    try {
      SBluePrint sBluePrint = SBluePrint.of(recordType);
      Assert.fail('Exception should be thrown');
    } catch (DmlException e) {
      String actual = e.getMessage();
      System.debug(actual);
      String expected = 'RecordType must not be null';
      Assert.areEqual(expected, actual);
    }
  }

  @isTest
  static void testOf_WhenRecordTypeIsNotSObject_ThenThrowException() {
    // Arrange
    System.Type recordType = String.class;

    // Act & Assert
    try {
      SBluePrint sBluePrint = SBluePrint.of(recordType);
      Assert.fail('Exception should be thrown');
    } catch (DmlException e) {
      String actual = e.getMessage();
      System.debug(actual);
      String expected = 'RecordType must be SObject type';
      Assert.areEqual(expected, actual);
    }
  }

  @isTest
  static void testSet_WhenAddFieldValue_ThenReturnNewSBluePrintWithFieldValue() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Account.class);
    String fieldName = 'Name';
    String fieldValue = 'Test Account';

    // Act
    SBluePrint newSBluePrint = sBluePrint.set(fieldName, fieldValue);

    // Assert
    Assert.areEqual('Test Account', newSBluePrint.fieldValues.get(fieldName).value, 'Field value should be set');
  }

  @isTest
  static void testTemplate_WhenAddTemplate_ThenReturnNewSBluePrint() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Account.class);
    Map<String, Object> template = new Map<String, Object>{ 'Name' => 'Test Account', 'Industry' => 'Technology' };

    // Act
    SBluePrint newSBluePrint = sBluePrint.template(template);

    // Assert
    Assert.areEqual(
      'Test Account',
      newSBluePrint.fieldValues.get('Name').value,
      'Name should be set from template'
    );
    Assert.areEqual(
      'Technology',
      newSBluePrint.fieldValues.get('Industry').value,
      'Industry should be set from template'
    );
  }

  @isTest
  static void testUse_WhenAddUseAlias_ThenReturnNewSBluePrintWithUseAlias() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Opportunity.class);
    String alias = 'parentAccount';
    String fromField = 'Id';
    String toField = 'AccountId';

    // Act
    SBluePrint newSBluePrint = sBluePrint.use(alias, fromField, toField);

    // Assert
    Assert.areEqual(1, newSBluePrint.useAliases.size(), 'UseAlias should be added');
    SBluePrint.UseAlias useAlias = newSBluePrint.useAliases[0];
    Assert.areEqual(alias, useAlias.alias, 'Alias should be set');
    Assert.areEqual(fromField, useAlias.fromField, 'FromField should be set');
    Assert.areEqual(toField, useAlias.toField, 'ToField should be set');
  }

  @isTest
  static void testAlias_WhenAddAlias_ThenReturnNewSBluePrintWithAlias() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Account.class);
    String alias = 'acc';

    // Act
    SBluePrint newSBluePrint = sBluePrint.alias(alias);

    // Assert
    Assert.areEqual(alias, newSBluePrint.alias, 'Alias should be set');
  }

  @isTest
  static void testTimes_WhenAddTimes_ThenReturnNewSBluePrintWithInsertNumber() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Account.class);
    Integer times = 5;

    // Act
    SBluePrint newSBluePrint = sBluePrint.times(times);

    // Assert
    Assert.areEqual(times, newSBluePrint.insertNumber, 'InsertNumber should be set');
  }

  @isTest
  static void testParentIdField_WhenAddParentIdField_ThenReturnNewSBluePrintWithParentIdField() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Contact.class);
    String parentIdField = 'AccountId';

    // Act
    SBluePrint newSBluePrint = sBluePrint.parentIdField(parentIdField);

    // Assert
    Assert.areEqual(parentIdField, newSBluePrint.parentIdField, 'ParentIdField should be set');
  }

  @isTest
  static void testAddChildren_WhenAddChild_ThenReturnNewSBluePrintWithChild() {
    // Arrange
    SBluePrint parent = SBluePrint.of(Account.class);
    SBluePrint child = SBluePrint.of(Contact.class);

    // Act
    SBluePrint newSBluePrint = parent.addChildren(child);

    // Assert
    Assert.areEqual(1, newSBluePrint.children.size(), 'Child should be added');
    Assert.areEqual(Contact.class, newSBluePrint.children[0].recordType, 'Child recordType should be Contact');
  }

  @isTest
  static void testAnalyze_WhenOnlyRoot_ThenReturnAnalysisResultWithOnlyRoot() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Account.class);
    SBluePrint.AutoAliasCounter autoAliasCounter = new SBluePrint.AutoAliasCounter();
    SBluePrint.AnalysisResult analysisResult = new SBluePrint.AnalysisResult();

    // Act
    sBluePrint.analyze(analysisResult, autoAliasCounter, null, null);

    // Assert
    List<SBluePrint> roots = analysisResult.getRoots();
    Assert.areEqual(1, roots.size(), 'There should be one root');
    Assert.isFalse(analysisResult.hasPending(), 'There should be no pending');
  }

  @isTest
  static void testAnalyze_WhenAddUsingAlias_ThenReturnAnalysisResultWithPending() {
    // Arrange
    SBluePrint sBluePrint = SBluePrint.of(Opportunity.class).use('parentAccount', 'Id', 'AccountId');
    SBluePrint.AutoAliasCounter autoAliasCounter = new SBluePrint.AutoAliasCounter();
    SBluePrint.AnalysisResult analysisResult = new SBluePrint.AnalysisResult();

    // Act
    sBluePrint.analyze(analysisResult, autoAliasCounter, null, null);

    // Assert
    List<SBluePrint> roots = analysisResult.getRoots();
    Assert.areEqual(0, roots.size(), 'There should be one root');
    Assert.isTrue(analysisResult.hasPending(), 'There should be pending');
  }

  @isTest
  static void testAnalyze_WhenAddChild_ThenReturnAnalysisResultWithRootAndPending() {
    // Arrange
    SBluePrint parent = SBluePrint.of(Account.class).addChildren(SBluePrint.of(Contact.class));
    SBluePrint.AutoAliasCounter autoAliasCounter = new SBluePrint.AutoAliasCounter();
    SBluePrint.AnalysisResult analysisResult = new SBluePrint.AnalysisResult();

    // Act
    parent.analyze(analysisResult, autoAliasCounter, null, null);

    // Assert
    List<SBluePrint> roots = analysisResult.getRoots();
    Assert.areEqual(1, roots.size(), 'There should be one root');
    Assert.isTrue(analysisResult.hasPending(), 'There should be pending');
  }

  @isTest
  static void testRealize_WhenAddBasicSBluePrint_ThenReturnSObject() {
    // Arrange
    Map<String, SObject> aliasToSObject = new Map<String, SObject>();
    Map<String, Object> template = new Map<String, Object>{ 'Industry' => 'Technology', 'Type' => 'Customer' };
    SBluePrint sBluePrint = SBluePrint.of(Account.class)
      .alias('acc')
      .set('Name', 'Test Account')
      .template(template);

    // Act
    sBluePrint.realize(aliasToSObject);

    // Assert
    Account acc = (Account) aliasToSObject.get('acc');
    Assert.areEqual('Test Account', acc.Name, 'Name should be set');
    Assert.areEqual('Technology', acc.Industry, 'Industry should be set from template');
    Assert.areEqual('Customer', acc.Type, 'Type should be set from template');
  }

  @isTest
  static void testRealize_WhenAddTimes_ThenReturnMultipleSObjects() {
    // Arrange
    Map<String, SObject> aliasToSObject = new Map<String, SObject>();
    SBluePrint sBluePrint = SBluePrint.of(Account.class)
      .alias('acc_{#}')
      .set('Name', 'Test Account {#}')
      .set('Industry', 'Industry_{A}')
      .set('Type', 'Type_{a}')
      .times(3);

    // Act
    sBluePrint.realize(aliasToSObject);

    // Assert acc1
    Account acc1 = (Account) aliasToSObject.get('acc_1');
    Assert.areEqual('Test Account 1', acc1.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_A', acc1.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_a', acc1.Type, 'Type should be set with sequence');
    // Assert acc2
    Account acc2 = (Account) aliasToSObject.get('acc_2');
    Assert.areEqual('Test Account 2', acc2.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_B', acc2.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_b', acc2.Type, 'Type should be set with sequence');
    // Assert acc3
    Account acc3 = (Account) aliasToSObject.get('acc_3');
    Assert.areEqual('Test Account 3', acc3.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_C', acc3.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_c', acc3.Type, 'Type should be set with sequence');
  }

  @isTest
  static void testRealize_WhenAddTmiesWithOffsetAndInterval_ThenReturnMultipleSObjects() {
    // Arrange
    Map<String, SObject> aliasToSObject = new Map<String, SObject>();
    SBluePrint sBluePrint = SBluePrint.of(Account.class)
      .alias('acc_{#}')
      .set('Name', 'Test Account {#}', 10, 2)
      .set('Industry', 'Industry_{A}', 5, 3) // Start from E, interval is 3
      .set('Type', 'Type_{a}', 8, 4) // Start from h, interval is 4
      .times(3);

    // Act
    sBluePrint.realize(aliasToSObject);

    // Assert acc1
    Account acc1 = (Account) aliasToSObject.get('acc_1');
    Assert.areEqual('Test Account 10', acc1.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_E', acc1.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_h', acc1.Type, 'Type should be set with sequence');
    // Assert acc2
    Account acc2 = (Account) aliasToSObject.get('acc_2');
    Assert.areEqual('Test Account 12', acc2.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_H', acc2.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_l', acc2.Type, 'Type should be set with sequence');
    // Assert acc3
    Account acc3 = (Account) aliasToSObject.get('acc_3');
    Assert.areEqual('Test Account 14', acc3.Name, 'Name should be set with sequence');
    Assert.areEqual('Industry_K', acc3.Industry, 'Industry should be set with sequence');
    Assert.areEqual('Type_p', acc3.Type, 'Type should be set with sequence');
  }

  @isTest
  static void TestRealize_WhenUseAliasButNotExistAlias_ThenThrowException() {
    // Arrange
    Map<String, SObject> aliasToSObject = new Map<String, SObject>();
    SBluePrint sBluePrint = SBluePrint.of(Opportunity.class)
      .alias('opp')
      .set('Name', 'Test Opportunity')
      .use('parentAccount', 'Id', 'AccountId'); // parentAccount alias does not exist

    // Act & Assert
    try {
      sBluePrint.realize(aliasToSObject);
      Assert.fail('Exception should be thrown');
    } catch (DmlException e) {
      String actual = e.getMessage();
      System.debug(actual);
      String expected = 'Alias \'parentAccount\' not found';
      Assert.areEqual(expected, actual);
    }
  }

  @isTest
  static void testRealize_WhenUseAlias_ThenReturnSObjectWithParentId() {
    // Arrange
    Account acc = new Account(Id = '001000000000000', Name = 'Test Account');
    Map<String, SObject> aliasToSObject = new Map<String, SObject>{ 'acc' => acc };
    SBluePrint sBluePrint = SBluePrint.of(Opportunity.class)
      .alias('opp')
      .set('Name', 'Test Opportunity')
      .use('acc', 'Id', 'AccountId'); // Use alias from parent

    // Act
    sBluePrint.realize(aliasToSObject);

    // Assert
    Opportunity opp = (Opportunity) aliasToSObject.get('opp');
    Assert.areEqual('Test Opportunity', opp.Name, 'Opportunity Name should be set');
    Assert.areEqual(acc.Id, opp.AccountId, 'Opportunity AccountId should be set from Account Id');
  }

  @isTest
  static void testRealize_WhenUseAliasWithTimes_ThenReturnMultipleSObjectsWithParentId() {
    // Arrange
    Account acc1 = new Account(Id = '001000000000000', Name = 'Test Account 1');
    Account acc2 = new Account(Id = '001000000000001', Name = 'Test Account 2');
    Map<String, SObject> aliasToSObject = new Map<String, SObject>{
      'acc_1' => acc1,
      'acc_2' => acc2
    };
    SBluePrint sBluePrint = SBluePrint.of(Opportunity.class)
      .alias('opp_{#}')
      .set('Name', 'Test Opportunity {#}')
      .use('acc_{#}', 'Id', 'AccountId') // Use alias from parent
      .times(2);

    // Act
    sBluePrint.realize(aliasToSObject);

    // Assert opp_1
    Opportunity opp1 = (Opportunity) aliasToSObject.get('opp_1');
    Assert.areEqual('Test Opportunity 1', opp1.Name, 'Opportunity Name should be set with sequence');
    Assert.areEqual(acc1.Id, opp1.AccountId, 'Opportunity AccountId should be set from Account Id');
    // Assert opp_2
    Opportunity opp2 = (Opportunity) aliasToSObject.get('opp_2');
    Assert.areEqual('Test Opportunity 2', opp2.Name, 'Opportunity Name should be set with sequence');
    Assert.areEqual(acc2.Id, opp2.AccountId, 'Opportunity AccountId should be set from Account Id');
  }
}
