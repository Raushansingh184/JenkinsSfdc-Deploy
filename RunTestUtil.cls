/* 	@Author 		: Nitin Patil
 * 	@CreatedDate 	: 5th June 2020 
 *	@Version		: 1.0
 *	@Desc			: This is a helper class referenced from RunTestScheduler Class & RunTestSendEmailScheduler Class 	
*/

public class RunTestUtil {
/* 	@Author 		: Nitin Patil 
 * 	@CreatedDate 	: 5th June 2020 
 *	@Version		: 1.0
 *	@Desc			: This enqueueTests() method is referenced from RunTestScheduler Class. 
					  This method enqueues All test classes or Test Classes mentioned in Run_Test__c Custom settings. 
*/
    public static void enqueueTests() {
        try{
           	List<String> testClassNames = Run_Test__c.getValues('Run Test Classes').Test_Classes__c != NULL ? Run_Test__c.getValues('Run Test Classes').Test_Classes__c.split(',') : new List<String>();
        	ApexClass[] testClasses = testClassNames.size()>0 ? [Select Id,Name from ApexClass where Name IN: testClassNames] : [SELECT Id FROM ApexClass 
            							WHERE Name LIKE '%Test'];            //new ApexClass[];
                
        	ApexTestQueueItem[] queueItems = new List<ApexTestQueueItem>();
        	Savepoint sp = Database.setSavepoint();
        
        	if (testClasses.size() > 0) {            
            	for (ApexClass cls : testClasses) {
                	queueItems.add(new ApexTestQueueItem(ApexClassId=cls.Id));
            	}
			}
        	if(!Test.isRunningTest()){
                	insert queueItems;     
            }            	
            if(queueItems.size()>0 && queueItems[0].Id != NULL ){                 
                	// Get the job ID of the first queue item returned.            	
            		ApexTestQueueItem item = [SELECT ParentJobId FROM ApexTestQueueItem WHERE Id=:queueItems[0].Id LIMIT 1];            
            
            		//Create custom object records            
            		Test_Run_Detail__c testRunDetailRecord = new Test_Run_Detail__c();
					testRunDetailRecord.Name = item.parentjobid;
            		testRunDetailRecord.Mode__c = Run_Test__c.getValues('Run Test Classes').Mode__c != NULL ? Run_Test__c.getValues('Run Test Classes').Mode__c : 'Failures';
        			testRunDetailRecord.Recipient_Emails__c = Run_Test__c.getValues('Run Test Classes').Recipient_Email_Ids__c != NULL ? Run_Test__c.getValues('Run Test Classes').Recipient_Email_Ids__c : UserInfo.getUserEmail() ;
        	
        			insert testRunDetailRecord;     
             }
               
        }
        catch(DMLException e){
            System.debug('**Exception Occurred While DML**'+e.getMessage()+e.getStackTraceString());
        }
        catch(Exception e){
            System.debug('**Exception Occurred**'+e.getMessage()+e.getStackTraceString());
        }
                
    }
    
/* 	@Author 		: Nitin Patil
 * 	@CreatedDate 	: 5th June 2020 
 *	@Version		: 1.0
 *	@Desc			: This checkAndSendEmailToRecipient() method is referenced from RunTestSendEmailScheduler Class. 
					  This method sends mail to Current user or Recipients email ids mentioned in Run_Test__c Custom settings.
					  This also deletes the successfully completed/aborted/failed records from Test_Run_Detail__c object.	
*/    
    public static void checkAndSendEmailToRecipient(){
        try{
           	Map<Id,Test_Run_Detail__c> testRunDetailMap = new Map<Id,Test_Run_Detail__c> (); 
            
            for(Test_Run_Detail__c rec : [SELECT Id, Name , Recipient_Emails__c,Mode__c FROM Test_Run_Detail__c LIMIT: Limits.getLimitQueryRows()]){
            	testRunDetailMap.put(rec.Name, rec);    
            }
        	Map<Id, set<String>> ApexClassAndMethodMap = new Map<Id, set<String>>();
            if(testRunDetailMap.size()>0){
            	for(ApexTestResult item : [SELECT AsyncApexJobId, ApexClassId, ApexClass.Name, MethodName, Outcome, Message FROM ApexTestResult WHERE AsyncApexJobId IN :testRunDetailMap.keySet()]){
            	String status = (item.Outcome == 'Pass' && item.Message == NULL) ? item.MethodName +' '+'Success \n' : item.MethodName +' '+'Failed \n';
            	if(testRunDetailMap.get(item.AsyncApexJobId).Mode__c == 'Always'){
                
                	if(ApexClassAndMethodMap.containsKey(item.AsyncApexJobId)){
                 
                    	ApexClassAndMethodMap.get(item.AsyncApexJobId).add(item.ApexClass.Name+' '+status);
                	}
                	else{
                    	ApexClassAndMethodMap.put(item.AsyncApexJobId, new Set<String>{item.ApexClass.Name+' '+status});
                	}
            	}
            	else if(item.Message != NULL){
                	if(ApexClassAndMethodMap.containsKey(item.AsyncApexJobId) ){
                    	ApexClassAndMethodMap.get(item.AsyncApexJobId).add(item.ApexClass.Name + ' ' + status);
                	}
                	else{
                    	ApexClassAndMethodMap.put(item.AsyncApexJobId, new Set<String>{item.ApexClass.Name +' '+status});
                	}
            	}
        	}    
            }    
        	
            
        	List<Test_Run_Detail__c> ListToDelete = new List<Test_Run_Detail__c>();
        	//List<ApexTestRunResult> ApexTestRunResultList = ;
        	
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            if(testRunDetailMap.size()>0){
            	for(ApexTestRunResult record : [SELECT AsyncApexJobId, ClassesEnqueued, EndTime, IsAllTests, MethodsFailed,Status FROM ApexTestRunResult WHERE AsyncApexJobId IN: testRunDetailMap.keySet() AND Status NOT IN ('Processing','Queued') Limit :Limits.getLimitQueryRows()]){    
            
            		ListToDelete.add(testRunDetailMap.get(record.AsyncApexJobId));	    
            
            		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            		List<String> emailIds  = testRunDetailMap.get(record.AsyncApexJobId).Recipient_Emails__c.split(',');
            		email.toaddresses = emailIds;
            		email.setSubject('Test Results'+System.today());
            		email.plaintextbody = 'Processed Test Classes : \n'+ ApexClassAndMethodMap.get(record.AsyncApexJobId).toString() + '\n'+'MethodsFailed'+record.MethodsFailed;
            		emails.add(email);
        		}    
            }         	
        	Messaging.sendEmail(emails);
            Delete ListToDelete;        	
        	
        }
        catch(DMLException e){
            	System.debug('**Error while deleting Test_Run_Detail__c records'+e.getMessage());
        } 
        catch(Exception e){
            System.debug('Exception Occurred'+e.getMessage());
        }
                
    }
}