public class OfferIntegrationService {
    public class JobAppInput {
        @InvocableVariable(required=true)
        public Id jobAppId;
    }

    @InvocableMethod(label='Send Offer Details to HR System')
    public static void sendOffer(List<JobAppInput> jobAppInputs) {
        List<Id> jobAppIds = new List<Id>();
        for (JobAppInput input : jobAppInputs) {
            jobAppIds.add(input.jobAppId);
        }

        sendCalloutAsync(jobAppIds);
    }

    @future(callout=true)
    public static void sendCalloutAsync(List<Id> jobAppIds) {
        List<Job_Application__c> apps = [
            SELECT Id, Name, Offered_Salary__c, Start_Date__c, Offer_Details_Sent_to_HR_System__c , Candidate__r.Email__c
            FROM Job_Application__c
            WHERE Id IN :jobAppIds
        ];
		boolean changed = false;
        for (Job_Application__c app : apps) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:MockOfferService');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            String body = JSON.serialize(new Map<String, Object>{
                'ApplicationId' => app.Id,
                'Candidate' => app.Candidate__r.Email__c,
                'StartDate' => app.Start_Date__c,
                'Salary' => app.Offered_Salary__c
            });
            req.setBody(body);

            Http http = new Http();
            try {
                HTTPResponse res = http.send(req);
                System.debug('Status: ' + res.getStatus());
                System.debug('Body: ' + res.getBody());
                if(res.getStatus()=='OK'){
                    app.Offer_Details_Sent_to_HR_System__c = true;
                    changed=true;
                }
                
            } catch (Exception e) {
                System.debug('Callout failed: ' + e.getMessage());
            }
        }
        if(changed){
            update apps;
        }
    }
}