public with sharing class BulkShortlistListController {
    public ApexPages.StandardSetController stdSetCtrl { get; set; }

    public BulkShortlistListController(ApexPages.StandardSetController controller) {
        this.stdSetCtrl = controller;
    }

    public PageReference processShortlist() {
        List<SObject> selectedRecords = stdSetCtrl.getSelected();
        Set<Id> recordIds = new Set<Id>();

        for (SObject record : selectedRecords) {
            recordIds.add(record.Id);
        }

        List<Job_Application__c> appsToUpdate = [
            SELECT Id, Status__c, Candidate__r.Name
            FROM Job_Application__c
            WHERE Id IN :recordIds
        ];

        List<Interview__c> interviews = new List<Interview__c>();
        DateTime baseTime = DateTime.newInstance(Date.today().addDays(1), Time.newInstance(10, 0, 0, 0));
        Integer counter = 0;

        for (Job_Application__c app : appsToUpdate) {
            app.Stage__c = 'Shortlisted';

            Interview__c interview = new Interview__c(
                Name = 'Interview for ' + app.Candidate__r.Name,
                Job_Application__c = app.Id,
                Interview_Date_Time__c = baseTime.addMinutes(counter * 30),
                Meeting_Link__c = 'https://zoom.us/fake-meeting'
            );
            interviews.add(interview);
            counter++;
        }

        update appsToUpdate;
        insert interviews;

        // Redirect back to the Job Application list view
        return new PageReference('/' + Schema.getGlobalDescribe().get('Job_Application__c').getDescribe().getKeyPrefix() + '/o');
    }
}