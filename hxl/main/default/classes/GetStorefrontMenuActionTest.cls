@IsTest
private class GetStorefrontMenuActionTest {
  private static final Id FAKE_STOREFRONT_ID = Id.valueOf(Storefront__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

  private class MockStorefrontService extends StorefrontService {
    private List<Menu_Item__c> menuItemsToReturn;
    private String exceptionMessage;

    public MockStorefrontService(List<Menu_Item__c> menuItems) {
      this.menuItemsToReturn = menuItems;
    }

    public MockStorefrontService(String exceptionMessage) {
      this.exceptionMessage = exceptionMessage;
    }

    public override Storefront__c getStorefrontFromName(String storefrontName) {
      if (exceptionMessage != null) {
        throw new StorefrontException(exceptionMessage);
      }
      return new Storefront__c(Id = FAKE_STOREFRONT_ID, Name = storefrontName);
    }

    public override List<Menu_Item__c> getMenuItems(Id storefrontId) {
      return menuItemsToReturn;
    }
  }

  private static List<GetStorefrontMenuAction.Output> run(String storefrontName) {
    GetStorefrontMenuAction.Input request = new GetStorefrontMenuAction.Input();
    request.storefrontName = storefrontName;
    Test.startTest();
    List<GetStorefrontMenuAction.Output> results = GetStorefrontMenuAction.getStorefrontMenu(
      new List<GetStorefrontMenuAction.Input>{ request }
    );
    Test.stopTest();
    return results;
  }

  @IsTest
  static void testGetStorefrontMenu_Success() {
    GetStorefrontMenuAction.storefrontService = new MockStorefrontService(
      new List<Menu_Item__c>{
        new Menu_Item__c(Name = 'Avocado Toast', Description__c = 'Smashed avocado on whole-grain bread.', Price__c = 12),
        new Menu_Item__c(Name = 'Chia Pudding', Description__c = 'Chia pudding with fresh berries.', Price__c = 8)
      }
    );

    GetStorefrontMenuAction.Output response = run('The Green Fork')[0];

    Assert.isTrue(response.isSuccess, 'Should indicate success');
    Assert.areEqual(FAKE_STOREFRONT_ID, response.storefrontId, 'Should return the storefront ID');
    Assert.areEqual('The Green Fork', response.menu.storefrontName, 'Should return the storefront name');
    Assert.areEqual(2, response.menu.items.size(), 'Should return one view per menu item');
    Assert.areEqual('$12.00', response.menu.items[0].priceLabel, 'Should format the price');
    Assert.areEqual('2 dishes · $8.00–$12.00', response.menu.summaryLabel, 'Should summarize count and price range');
  }

  @IsTest
  static void testGetStorefrontMenu_NoItems() {
    GetStorefrontMenuAction.storefrontService = new MockStorefrontService(new List<Menu_Item__c>());

    GetStorefrontMenuAction.Output response = run('The Green Fork')[0];

    Assert.isFalse(response.isSuccess, 'Should indicate failure when there are no items');
    Assert.areEqual('0 dishes', response.menu.summaryLabel, 'Should summarize an empty menu');
    Assert.isTrue(response.message.contains('No menu items'), 'Should explain that no items were found');
  }

  @IsTest
  static void testGetStorefrontMenu_StorefrontNotFound() {
    GetStorefrontMenuAction.storefrontService = new MockStorefrontService('No storefront found with name: Nowhere');

    GetStorefrontMenuAction.Output response = run('Nowhere')[0];

    Assert.isFalse(response.isSuccess, 'Should indicate failure');
    Assert.isNull(response.menu, 'Should not return a menu');
    Assert.areEqual('No storefront found with name: Nowhere', response.message, 'Should return the service message');
  }

  @IsTest
  static void testFormatters() {
    Assert.areEqual('', GetStorefrontMenuAction.formatPrice(null), 'Null price should be blank');
    Assert.areEqual('$9.50', GetStorefrontMenuAction.formatPrice(9.5), 'Should pad to two decimals');
    Assert.areEqual('1 dish · $9.00', GetStorefrontMenuAction.formatSummaryLabel(1, 9, 9), 'Single price should not show a range');
    Assert.areEqual('3 dishes', GetStorefrontMenuAction.formatSummaryLabel(3, null, null), 'Missing prices should omit the range');
  }
}
