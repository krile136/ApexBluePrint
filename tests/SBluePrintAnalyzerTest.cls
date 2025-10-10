@isTest
public with sharing class SBluePrintAnalyzerTest {
  @isTest
  static void test() {
    List<SBluePrint> bluePrints = new List<SBluePrint>();

    bluePrints.add(
      SBluePrint.of(Account.class)
          .withChildren(SBluePrint.of(Opportunity.class)
            .parentIdField('AccountId')
            .withChildren(SBluePrint.of(UW_Quote__c.class)
              .parentIdField('Opportunity__c')
            )
          )
    );

    SBluePrintAnalyzer analyzer = new SBluePrintAnalyzer(bluePrints);  
    SOrchestrator.BuildLayers buildLayers = analyzer.analyze();
  }

  @isTest
  static void test2() {
    List<SBluePrint> bluePrints = new List<SBluePrint>();

    bluePrints.add(
      SBluePrint.of(Opportunity.class)
        .use('acc', 'Id', 'AccountId')
        .alias('opp')
    );
    bluePrints.add( 
      SBluePrint.of(UW_Quote__c.class)
        .use('opp', 'Id', 'Opportunity__c')
    );
    bluePrints.add(
      SBluePrint.of(Account.class)
        .alias('acc')
    );
      
    SBluePrintAnalyzer analyzer = new SBluePrintAnalyzer(bluePrints);  
    SOrchestrator.BuildLayers buildLayers = analyzer.analyze();
  }
}
