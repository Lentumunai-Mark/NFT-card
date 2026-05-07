trigger IncentivesCalculatorTrigger on Loan__c (after insert, after update) {
    
    // Only process one loan at a time for now
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            for (Loan__c loan : Trigger.new) {
                IncentiveCalculator.calculateIncentives(loan.Id);
            }
        }
    }
}