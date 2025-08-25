public with sharing class BulkShortlistScheduler {
    @AuraEnabled
    public static void shortlistAndSchedule(List<Id> jobAppIds) {
        // Fetch Job Applications with Candidates
        List<Job_Application__c> apps = [
            SELECT Id, Status__c, Candidate__r.Name, Candidate__c
            FROM Job_Application__c
            WHERE Id IN :jobAppIds
        ];

        // Fetch 2 Interviewers
        List<Interviewer__c> interviewers = [
            SELECT Id FROM Interviewer__c LIMIT 2
        ];

        if (interviewers.size() < 2) {
            throw new AuraHandledException('At least 2 Interviewer__c records are required.');
        }

        List<Interview__c> interviews = new List<Interview__c>();
        DateTime startTime = DateTime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)); // Today 10 AM
        Integer slotIncrementMins = 30;
        Integer interviewerIndex = 0;
        Integer count = 0;

        for (Job_Application__c app : apps) {
            app.Status__c = 'Shortlisted';

            Interview__c interview = new Interview__c();
            interview.Name = 'Interview for ' + app.Candidate__r.Name;
            interview.Job_Application__c = app.Id;
            interview.Interview_Date_Time__c = startTime.addMinutes(count * slotIncrementMins);
            interview.Interviewer__c = interviewers[interviewerIndex].Id;
            interview.Meeting_Link__c = 'https://zoom.us/fake-meeting';

            // Alternate Interviewer
            interviewerIndex = Math.mod((interviewerIndex + 1) ,interviewers.size());
            count++;
            

            interviews.add(interview);
        }

        update apps;
        insert interviews;
    }
}