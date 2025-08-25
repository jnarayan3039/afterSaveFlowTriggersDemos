public with sharing class InterviewRoundRobinAction {
    // ----- Flow I/O -----
    public class Request {
        @InvocableVariable(required=true)
        public String poolKey;               // e.g., Position Id, "ENG-US", etc.

        @InvocableVariable
        public Integer howMany;              // defaults to 1

        // Optional: If you want to override pool via Flow, pass Interviewer__c Ids here
        @InvocableVariable
        public List<Id> eligibleInterviewerIds; // <-- INTERVIEWER Ids (not User Ids)
    }
    public class Result {
        // Primary outputs you will use in Flow:
        @InvocableVariable public List<Id> pickedInterviewerIds;
        @InvocableVariable public Id pickedInterviewerId; // convenience: first pick

        // Optional extras (if you also want the underlying User/Employee Ids)
        @InvocableVariable public List<Id> pickedUserIds;
        @InvocableVariable public Id pickedUserId;

        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Round Robin – Pick Interviewers (returns Interviewer Ids)'
                     description='Picks next N Interviewer__c per pool, concurrency-safe; returns Interviewer Ids and related User Ids.')
    public static List<Result> pickInterviewers(List<Request> requests) {
        List<Result> outs = new List<Result>();
        if (requests == null || requests.isEmpty()) return outs;

        // Gather pools
        Set<String> poolKeys = new Set<String>();
        for (Request r : requests) if (r != null && !String.isBlank(r.poolKey)) poolKeys.add(r.poolKey.trim());

        // Lock tracker rows for these pools
        Map<String, Round_Robin_Tracker__c> trackerByKey = new Map<String, Round_Robin_Tracker__c>();
        if (!poolKeys.isEmpty()) {
            for (Round_Robin_Tracker__c t : [
                SELECT Id, Pool_Key__c, Last_Index__c
                FROM Round_Robin_Tracker__c
                WHERE Pool_Key__c IN :poolKeys
                FOR UPDATE
            ]) trackerByKey.put(t.Pool_Key__c, t);
            for (String key : poolKeys) {
                if (!trackerByKey.containsKey(key)) {
                    trackerByKey.put(key, new Round_Robin_Tracker__c(
                        Pool_Key__c   = key,
                        Last_Index__c = -1
                    ));
                }
            }
        }

        // Build Interviewer pools from your table, grouped by pool key
        // Only Active interviewers whose linked User is Active
        Map<String, List<Interviewer__c>> poolInterviewerByKey = new Map<String, List<Interviewer__c>>();
        if (!poolKeys.isEmpty()) {
            for (Interviewer__c iv : [
                SELECT Id, Pool_Key__c, Active__c, Employee__c, Employee__r.IsActive
                FROM Interviewer__c
                WHERE Pool_Key__c IN :poolKeys
                  AND Active__c = true
                  AND Employee__c != null
            ]) {
                if (iv.Employee__r != null && iv.Employee__r.IsActive) {
                    if (!poolInterviewerByKey.containsKey(iv.Pool_Key__c)) {
                        poolInterviewerByKey.put(iv.Pool_Key__c, new List<Interviewer__c>());
                    }
                    poolInterviewerByKey.get(iv.Pool_Key__c).add(iv);
                }
            }
        }

        List<Round_Robin_Tracker__c> toUpsert = new List<Round_Robin_Tracker__c>();

        // Process each request
        for (Request r : requests) {
            Result res = new Result();
            res.pickedInterviewerIds = new List<Id>();
            res.pickedUserIds        = new List<Id>();

            if (r == null || String.isBlank(r.poolKey)) {
                res.message = 'Missing poolKey.'; outs.add(res); continue;
            }
            String poolKey = r.poolKey.trim();
            Integer need = (r.howMany == null || r.howMany <= 0) ? 1 : r.howMany;

            // Determine pool list (of Interviewer__c)
            List<Interviewer__c> pool;
            if (r.eligibleInterviewerIds != null && !r.eligibleInterviewerIds.isEmpty()) {
                // Flow-supplied Interviewer Ids → re-query to ensure active + has user + in this pool
                pool = [
                    SELECT Id, Pool_Key__c, Active__c, Employee__c, Employee__r.IsActive
                    FROM Interviewer__c
                    WHERE Id IN :r.eligibleInterviewerIds
                      AND Active__c = true
                      AND Employee__c != null
                      AND Employee__r.IsActive = true
                ];
            } else {
                pool = poolInterviewerByKey.get(poolKey);
            }

            if (pool == null || pool.isEmpty()) {
                res.message = 'No eligible Interviewer__c found for pool ' + poolKey;
                outs.add(res);
                continue;
            }

            // Round-robin using tracker
            Round_Robin_Tracker__c tracker = trackerByKey.get(poolKey);
            Integer last   = (tracker.Last_Index__c == null) ? -1 : Integer.valueOf(tracker.Last_Index__c);
            Integer size   = pool.size();
            Integer cursor = last;

            for (Integer i = 0; i < need; i++) {
                cursor = Math.mod((cursor + 1), size);
                Interviewer__c picked = pool[cursor];
                res.pickedInterviewerIds.add(picked.Id);
                if (picked.Employee__c != null) res.pickedUserIds.add(picked.Employee__c);
            }

            // convenience singletons
            if (!res.pickedInterviewerIds.isEmpty()) res.pickedInterviewerId = res.pickedInterviewerIds[0];
            if (!res.pickedUserIds.isEmpty())        res.pickedUserId        = res.pickedUserIds[0];

            // advance tracker
            tracker.Last_Index__c = cursor;
            toUpsert.add(tracker);

            res.message = 'Picked ' + res.pickedInterviewerIds.size() + ' interviewer(s) for pool ' + poolKey;
            outs.add(res);
        }

        if (!toUpsert.isEmpty()) upsert toUpsert;
        return outs;
    }
}