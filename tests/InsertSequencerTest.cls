@isTest
public with sharing class InsertSequencerTest {
  static void testInsertSequencer() {
    InsertSequencer.start()
    .insert(SRecord.of(new Product2())
      .template(new Map<String, Object>{    // テンプレートで値を共通化して渡すことが可能
        'IsActive' => true,
        'Family' => 'Test Family'
      })
      .set('Description', 'test Product Description') // 共通の値をセット
      .set('Name', 'Test Product {A}')  // 大文字の連番を付与
      .set('ProductCode', 'TP00{a}', 10)  // 小文字の連番を付与、開始番号は10(j)
      .set('ListPrice', '{#}', 50000, 10000) // 数字の連番を付与、開始番号は50000、インターバルは10000
      .alias('product_{#}') // 後続の処理がアクセスできるエイリアスを、連番で付与
      .times(5) // 5件作成
    ).insert(SRecord.of(new Account())
      .set('Name', 'Test Account')
      .alias('acc')
      .addChildren(SRecord.of(new Opportunity())  // このレコードを作成。自動的に親レコードのIDがセットされる。親IDをセットする候補が複数ある場合はエラーを出す
        .relationField('AccountId') // 親IDをセットする候補が複数ある場合はrelationNameを指定する
        .set('Name', 'Test Opportunity {#}', 1) // 数字の連番を付与、開始番号は1、インターバルは1
        .set('CloseDate', Date.today().addDays(30))
        .set('StageName', 'Prospecting')
        .addChildren(SRecord.of(new UW_Quote__c())
          .set('Name', 'Test Quote {#}', 1) // 数字の連番を付与、開始番号は1、インターバルは1
          .set('QuoteCode__c', 'TQ00{#}', 1, 1) // 数字の連番を付与、開始番号は1、インターバルは1
          .set('KENSHUU_Date__c', null)
          .addChildren(SRecord.of(new UW_QuoteItem__c())
            .set('Quantity__c', 2)
            .useAlias('product_{#}', 'Id') // エイリアスで参照可能
            .set('Quantity__c', '{#}', 1, 1) // 数字の連番を付与、開始番号は1、インターバルは1
            .times(2) // 2件作成
          )
        )
      )
    );

    JSON.deserialize
  }
}
