/**
 * Invocable Action for retrieving a storefront's menu by the storefront name,
 * shaped for display in the storefrontMenu HXL widget
 */
global with sharing class GetStorefrontMenuAction {
  @TestVisible
  private static StorefrontService storefrontService = new StorefrontService();

  /**
   * Retrieves the available menu items for a storefront by its name
   * @param inputs List of request objects containing the storefront name
   * @return List of response objects containing the display-ready menu
   */
  @InvocableMethod(
    label='Get Storefront Menu'
    description='Retrieves the available menu items for a storefront by its name, with display-ready prices'
    category='Storefront Management'
  )
  global static List<Output> getStorefrontMenu(List<Input> inputs) {
    List<Output> responses = new List<Output>();
    for (Input request : inputs) {
      Output response = new Output();
      try {
        Storefront__c storefront = storefrontService.getStorefrontFromName(request.storefrontName);
        List<Menu_Item__c> menuItems = storefrontService.getMenuItems(storefront.Id);
        response.menu = toMenu(storefront.Name, menuItems);
        response.storefrontId = storefront.Id;
        response.isSuccess = !menuItems.isEmpty();
        response.message = menuItems.isEmpty()
          ? 'No menu items found for storefront: ' + storefront.Name
          : 'Menu retrieved successfully';
      } catch (StorefrontService.StorefrontException e) {
        response.isSuccess = false;
        response.message = e.getMessage();
      }
      responses.add(response);
    }
    return responses;
  }

  /**
   * Input parameters for the invocable action
   */
  global class Input {
    @InvocableVariable(label='Storefront Name' description='The name of the storefront whose menu is retrieved' required=true)
    public String storefrontName;
  }

  /**
   * Response from the invocable action
   */
  global class Output {
    @InvocableVariable(label='Menu' description='Display-ready storefront menu')
    public StorefrontMenu menu;

    @InvocableVariable(label='Storefront ID' description='The ID of the storefront')
    public Id storefrontId;

    @InvocableVariable(label='Message' description='Success or error message')
    public String message;

    @InvocableVariable(label='Is Success' description='Indicates whether menu items were retrieved')
    public Boolean isSuccess;
  }

  /**
   * Display-ready menu: a widget can't compute values, so labels are built here
   */
  global class StorefrontMenu {
    @InvocableVariable
    public String storefrontName;
    @InvocableVariable
    public String summaryLabel;
    @InvocableVariable
    public List<MenuItemView> items;
  }

  /**
   * One display-ready menu item
   */
  global class MenuItemView {
    @InvocableVariable
    public String name;
    @InvocableVariable
    public String description;
    @InvocableVariable
    public String priceLabel;
  }

  @TestVisible
  private static StorefrontMenu toMenu(String storefrontName, List<Menu_Item__c> menuItems) {
    StorefrontMenu menu = new StorefrontMenu();
    menu.storefrontName = storefrontName;
    menu.items = new List<MenuItemView>();
    Decimal lowest;
    Decimal highest;
    for (Menu_Item__c record : menuItems) {
      MenuItemView item = new MenuItemView();
      item.name = record.Name;
      item.description = record.Description__c;
      item.priceLabel = formatPrice(record.Price__c);
      menu.items.add(item);
      if (record.Price__c != null) {
        lowest = lowest == null ? record.Price__c : Math.min(lowest, record.Price__c);
        highest = highest == null ? record.Price__c : Math.max(highest, record.Price__c);
      }
    }
    menu.summaryLabel = formatSummaryLabel(menuItems.size(), lowest, highest);
    return menu;
  }

  @TestVisible
  private static String formatPrice(Decimal price) {
    if (price == null) return '';
    return '$' + String.valueOf(price.setScale(2));
  }

  @TestVisible
  private static String formatSummaryLabel(Integer itemCount, Decimal lowest, Decimal highest) {
    String label = itemCount + (itemCount == 1 ? ' dish' : ' dishes');
    if (lowest == null || highest == null) return label;
    if (lowest == highest) return label + ' · ' + formatPrice(lowest);
    return label + ' · ' + formatPrice(lowest) + '–' + formatPrice(highest);
  }
}
