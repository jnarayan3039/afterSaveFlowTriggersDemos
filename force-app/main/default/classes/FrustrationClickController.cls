public with sharing class FrustrationClickController {
    @AuraEnabled
    public static void scheduleInterview(Id jobAppId) {
        // Simulate server delay
        Long start = DateTime.now().getTime();
        while (DateTime.now().getTime() - start < 4000) {
            // wait for 4 seconds
        }

        Job_Application__c app = [
            SELECT Id, Candidate__r.Name
            FROM Job_Application__c
            WHERE Id = :jobAppId
            LIMIT 1
        ];

        Interview__c interview = new Interview__c(
            Name = 'Interview for ' + app.Candidate__r.Name,
            Job_Application__c = app.Id,
            Interview_Date_Time__c = System.now().addDays(1),
            Meeting_Link__c = 'https://zoom.us/fake-meeting'
        );

        insert interview;
    }
}