```java

public class IncentiveCalculator {
    public static Map<String, Double> incentivesConstants = 
        IncentiveCalculatorConstants.loadConstants();
    
    public static void calculateIncentives(Set<Id> loanIds){
        List<Loan__c> loans = [
            SELECT
                Id,
                Loan_Amount__c,
                Borrower_Status_New__c,
                Account__c,
                Impact_Points__c,
                Bonuses__c,
                Revenue__c,
                Country_New__c
            FROM Loan__c
            WHERE Id IN :loanIds
        ];

    
        // Collect account IDs first
        Set<Id> accountIds = new Set<Id>();
        for(Loan__c loan : loans) {
            accountIds.add(loan.Account__c);
        }
    
        // Bulk queries — all outside the loop
        Map<Id, List<Loan_Balance__c>> balancesByLoan = new Map<Id, List<Loan_Balance__c>>();
        for(Loan_Balance__c b : [SELECT Loan__c, End_of_Month_Balance__c 
                                  FROM Loan_Balance__c WHERE Loan__c IN :loanIds]) {
            if(!balancesByLoan.containsKey(b.Loan__c))
                balancesByLoan.put(b.Loan__c, new List<Loan_Balance__c>());
            balancesByLoan.get(b.Loan__c).add(b);
        }
    
        Map<Id, Account> accountsById = new Map<Id, Account>(
            [SELECT Id, IP_Qualified__c, FLC_Qualified__c, OI_Qualified__c 
             FROM Account WHERE Id IN :accountIds]
        );
    
        Map<Id, ESG_Standard__c> esgByAccount = new Map<Id, ESG_Standard__c>();
        for(ESG_Standard__c esg : [SELECT Account__c, Youth_Owned__c, Climate_Smart__c, 
                                           Gender_Inclusive__c 
                                    FROM ESG_Standard__c WHERE Account__c IN :accountIds]) {
            esgByAccount.put(esg.Account__c, esg);
        }
    
        // Now loop — zero SOQL inside
        List<Incentive__c> incentivesToUpsert = new List<Incentive__c>();
        for(Loan__c loan : loans){
            Account account = accountsById.get(loan.Account__c);
            if(account == null || !account.IP_Qualified__c) continue;
    
            List<Loan_Balance__c> balances = balancesByLoan.containsKey(loan.Id) 
                ? balancesByLoan.get(loan.Id) : new List<Loan_Balance__c>();
    
            ESG_Standard__c esg = esgByAccount.containsKey(loan.Account__c)
                ? esgByAccount.get(loan.Account__c)
                : new ESG_Standard__c(Youth_Owned__c=false, Climate_Smart__c=false, Gender_Inclusive__c=false);
    
            Incentive__c incentive = new Incentive__c(Loan__c = loan.Id);
            if(account.FLC_Qualified__c) incentive.Max_FLC__c = calculateMaxFLC(loan);
            if(account.OI_Qualified__c)  incentive.Max_OI__c  = calculateMaxOI(loan, esg);
            incentive.Quarterly_Earnings__c = calculateQuarterlyEarnings(balances);
    
            incentivesToUpsert.add(incentive);
        }
    
        if(!incentivesToUpsert.isEmpty()) upsert incentivesToUpsert;
    }
    
    public static Decimal calculateMaxFLC(Loan__c loan) {
        if (loan.Loan_Amount__c == null) {
            return 0;
        }

        Decimal baseFactor = incentivesConstants.get('baseFactor');
        Decimal factorIncrement = 0;

        // Returning borrowers get extra increment
        if (!String.isBlank(loan.Borrower_Status_New__c) && 
            loan.Borrower_Status_New__c.contains('Returning')) {
            factorIncrement = incentivesConstants.get('factorIncrement');
        }

        Decimal totalFactor = baseFactor + factorIncrement +
            (loan.Impact_Points__c != null 
                ? loan.Impact_Points__c * incentivesConstants.get('oILoanBasImpactConstant')
                : 0);

        return loan.Loan_Amount__c * totalFactor;
    }
    
        public static Decimal calculateMaxOI(Loan__c loan, ESG_Standard__c esgStandard) {
        Decimal baseOI = 0;
        Decimal impactFactor = 0;

        // Check loan amount threshold
        if (loan.Loan_Amount__c == null || 
            loan.Loan_Amount__c < incentivesConstants.get('oILoanAmountThreshold')) {
            return 0;
        }

        // Base OI from revenue
        if (loan.Revenue__c != null && 
            loan.Revenue__c >= incentivesConstants.get('oIRevenueThreshold')) {
            baseOI = loan.Revenue__c * incentivesConstants.get('baseOIConstant');
        }

        // Impact points
        if (loan.Impact_Points__c != null) {
            impactFactor = loan.Impact_Points__c * 
                incentivesConstants.get('oILoanBasImpactConstant');
        }

        // ESG Bonuses
        if (esgStandard.Youth_Owned__c) {
            baseOI += incentivesConstants.get('eSGYouthOwnedBonus');
        }
        if (esgStandard.Climate_Smart__c) {
            baseOI += incentivesConstants.get('eSGClimateSmartBonus');
        }
        if (esgStandard.Gender_Inclusive__c) {
            baseOI += incentivesConstants.get('eSGGenderInclusiveBonus');
        }

        // Country adjustment
        if (!String.isBlank(loan.Country_New__c) && 
            (loan.Country_New__c.contains('Kenya') || 
             loan.Country_New__c.contains('Tanzania'))) {
            baseOI *= incentivesConstants.get('countryAdjustment');
        }

        return baseOI + impactFactor;
    }
    
    public static Decimal calculateQuarterlyEarnings(List<Loan_Balance__c> balances) {
        if (balances == null || balances.isEmpty()) {
            return 0;
        }

        Decimal quarterlyEarnings = 0;

        for (Loan_Balance__c balance : balances) {
            Decimal balanceOI = balance.End_of_Month_Balance__c * 
                incentivesConstants.get('balanceOIConstant');
            Decimal balanceFLC = balance.End_of_Month_Balance__c * 
                incentivesConstants.get('balanceFLCConstant');
            quarterlyEarnings += balanceOI + balanceFLC;
        }

        return quarterlyEarnings;
    }

}
```
