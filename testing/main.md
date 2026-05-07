```java

public class LoanTriggerHandler {
    
    private static Boolean alreadyRun = false;
    
    
    public static void handle(List<Loan__c> newLoans, Map<Id, Loan__c> oldMap, System.TriggerOperation operationType){
        
        
        if(alreadyRun){
            return;
        }
        
        alreadyRun = true;
        
        if(operationType == System.TriggerOperation.AFTER_INSERT){
            handleAfterInsert(newLoans);
        }else if(operationType == System.TriggerOperation.AFTER_UPDATE){
            handleAfterUpdate(newLoans, oldMap);
        }
        
    }
    
    public static  void handleAfterInsert(List<Loan__c> loans){
        Set<Id> loanIds = new Set<Id>();
        
        for(Loan__c loan: loans){
            loanIds.add(loan.Id);
        }
        //calculate incentives
        IncentiveCalculator.calculateIncentives(loanIds);
        
    }
    
    
    public static void handleAfterUpdate(List<Loan__c> newLoans, Map<Id, Loan__c> oldMap){
        
        Set<Id> loanIdsToProcess = new Set<Id>();
        
        for (Loan__c loan : newLoans) {
            Loan__c oldLoan = oldMap.get(loan.Id);
            
            // Only recalculate if relevant fields changed
            if (
                loan.Loan_Amount__c != oldLoan.Loan_Amount__c ||
                loan.Revenue__c != oldLoan.Revenue__c ||
                loan.Account__c != oldLoan.Account__c ||
                loan.Borrower_Status_New__c != oldLoan.Borrower_Status_New__c ||
                loan.Impact_Points__c != oldLoan.Impact_Points__c ||
                loan.Country_New__c != oldLoan.Country_New__c
            ) {
                loanIdsToProcess.add(loan.Id);
            }
        }
        
        if (!loanIdsToProcess.isEmpty()) {
            IncentiveCalculator.calculateIncentives(loanIdsToProcess);
        }
        
    }

}
```