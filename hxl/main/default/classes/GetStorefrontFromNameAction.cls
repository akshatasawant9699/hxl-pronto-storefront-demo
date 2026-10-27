/**
 * Invocable Action for retrieving a storefront by its name.
 * HXL series version: Output.storefront is a display-ready StorefrontDetails
 * (a widget has no JavaScript, so formatting happens here).
 */
global with sharing class GetStorefrontFromNameAction {
  @TestVisible
  private static StorefrontService storefrontService = new StorefrontService();

  @InvocableMethod(
    label='Get Storefront From Name'
    description='Retrieves a storefront record by its name'
    category='Storefront Management'
  )
  global static List<Output> getStorefrontFromName(List<Input> inputs) {
    List<Output> responses = new List<Output>();
    for (Input request : inputs) {
      Output response = new Output();
      try {
        Storefront__c record = storefrontService.getStorefrontFromName(request.storefrontName);
        response.storefront = toDetails(record);
        response.storefrontId = record.Id;
        response.message = 'Storefront retrieved successfully';
        response.isSuccess = true;
      } catch (StorefrontService.StorefrontException e) {
        response.message = e.getMessage();
        response.isSuccess = false;
      }
      responses.add(response);
    }
    return responses;
  }

  @TestVisible
  private static StorefrontDetails toDetails(Storefront__c record) {
    StorefrontDetails details = new StorefrontDetails();
    details.name = record.Name;
    details.cuisine = record.Cuisine__c;
    details.status = record.Status__c;
    details.statusVariant = toStatusVariant(record.Status__c);
    details.ratingLabel = formatRatingLabel(record.Average_Review_Score__c, record.Total_Reviews__c);
    details.address = formatAddress(record.Address__Street__s, record.Address__City__s, record.Address__StateCode__s);
    details.phone = record.Phone__c;
    return details;
  }

  @TestVisible
  private static String toStatusVariant(String status) {
    switch on status {
      when 'Active' { return 'success'; }
      when 'Pending Activation' { return 'warning'; }
      when 'Suspended' { return 'error'; }
      when else { return 'secondary'; }
    }
  }

  @TestVisible
  private static String formatRatingLabel(Decimal score, Decimal reviewCount) {
    if (score == null || reviewCount == null) {
      return '';
    }
    return score.setScale(1) + ' (' + reviewCount.intValue() + ' reviews)';
  }

  @TestVisible
  private static String formatAddress(String street, String city, String stateCode) {
    List<String> parts = new List<String>();
    for (String part : new List<String>{ street, city, stateCode }) {
      if (String.isNotBlank(part)) {
        parts.add(part);
      }
    }
    return String.join(parts, ', ');
  }

  global class Input {
    @InvocableVariable(label='Storefront Name' description='The name of the storefront to retrieve' required=true)
    public String storefrontName;
  }

  global class Output {
    @InvocableVariable(label='Storefront' description='Display-ready storefront details')
    public StorefrontDetails storefront;

    @InvocableVariable(label='Storefront ID' description='The ID of the retrieved storefront')
    public String storefrontId;

    @InvocableVariable(label='Message' description='Success or error message')
    public String message;

    @InvocableVariable(label='Is Success' description='Indicates whether the storefront was retrieved successfully')
    public Boolean isSuccess;
  }

  global class StorefrontDetails {
    @AuraEnabled public String name;
    @AuraEnabled public String cuisine;
    @AuraEnabled public String status;
    @AuraEnabled public String statusVariant;
    @AuraEnabled public String ratingLabel;
    @AuraEnabled public String address;
    @AuraEnabled public String phone;
  }
}
