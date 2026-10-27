/**
 * Test class for StoreReviewSummaryAiJob and AiJobRunTriggerHandler.
 */
@IsTest
private class StoreReviewSummaryAiJobTest {
  @TestSetup
  static void setupTestData() {
    List<Storefront__c> storefronts = TestDataFactory.createStorefronts(2, true);
    TestDataFactory.createReviews(storefronts[0].Id, 2, true);
    TestDataFactory.createReviews(storefronts[1].Id, 2, true);
    storefronts[1].Review_Summary__c = 'Existing summary';
    update storefronts[1];
  }

  @IsTest
  static void shouldQueueAllReviewedStorefronts_WhenForceRefresh() {
    Test.startTest();
    StoreReviewSummaryAiJob.startJob(true);
    Test.stopTest();

    AiJobRun jobRun = [SELECT Id, Status FROM AiJobRun WHERE Target = :StoreReviewSummaryAiJob.PROMPT_TEMPLATE_NAME];
    Assert.areEqual('ReadyToStart', jobRun.Status, 'Job should be started');
    Assert.areEqual(2, [SELECT COUNT() FROM AiJobRunItem WHERE AiJobRunId = :jobRun.Id], 'Should queue every reviewed storefront');
  }

  @IsTest
  static void shouldSkipSummarizedStorefronts_WhenNotForceRefresh() {
    Test.startTest();
    StoreReviewSummaryAiJob.startJob(false);
    Test.stopTest();

    AiJobRun jobRun = [SELECT Id FROM AiJobRun WHERE Target = :StoreReviewSummaryAiJob.PROMPT_TEMPLATE_NAME];
    Assert.areEqual(1, [SELECT COUNT() FROM AiJobRunItem WHERE AiJobRunId = :jobRun.Id], 'Should skip storefronts that already have a summary');
  }

  @IsTest
  static void shouldApplySummaries_FromCompletedItems() {
    // Given: only the AI job engine can mark items Completed, so build them in memory.
    Storefront__c storefront = [SELECT Id FROM Storefront__c WHERE Name = :TestDataFactory.STOREFRONT_NAME_PREFIX + '0'];
    List<AiJobRunItem> items = new List<AiJobRunItem>{
      new AiJobRunItem(
        Input = '{"Input:storefront": {"id":"' + storefront.Id + '"}}',
        Response = '{"promptResponse":"<p>Customers love it.</p>"}'
      ),
      new AiJobRunItem(Input = 'not json', Response = 'not json')
    };

    // When
    Test.startTest();
    StoreReviewSummaryAiJob.applySummaries(items);
    Test.stopTest();

    // Then
    Storefront__c updated = [SELECT Review_Summary__c FROM Storefront__c WHERE Id = :storefront.Id];
    Assert.areEqual('<p>Customers love it.</p>', updated.Review_Summary__c, 'Summary should be applied from the job response');
  }

  @IsTest
  static void shouldRouteCompletedJobs_FromTriggerHandler() {
    // Given
    AiJobRun jobRun = new AiJobRun(
      JobType = 'PromptTemplate',
      Target = StoreReviewSummaryAiJob.PROMPT_TEMPLATE_NAME,
      Label = 'Test run'
    );
    insert jobRun;
    // The platform won't let a test move a run to Completed, so drive the handler directly.
    AiJobRun completed = new AiJobRun(Id = jobRun.Id, JobType = jobRun.JobType, Target = jobRun.Target, Status = 'Completed');

    // When
    Test.startTest();
    AiJobRunTriggerHandler.handleAfterUpdate(new List<AiJobRun>{ jobRun }, new List<AiJobRun>{ completed });
    Test.stopTest();

    // Then: no completed items exist, so nothing changes
    Storefront__c unsummarized = [SELECT Review_Summary__c FROM Storefront__c WHERE Name = :TestDataFactory.STOREFRONT_NAME_PREFIX + '0'];
    Assert.isNull(unsummarized.Review_Summary__c, 'No storefronts should change');
  }
}