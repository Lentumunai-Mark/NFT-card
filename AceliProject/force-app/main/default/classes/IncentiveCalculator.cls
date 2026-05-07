public class IncentiveCalculator {

    // Load constants from Custom Metadata
    public static Map<String, Double> incentivesConstants = 
        IncentiveCalculatorConstants.loadConstants();

    // MAIN METHOD - entry point
    public static void calculateIncentives(Id loanId) {

        // Step 1 - Query the loan
        Loan__c loan = [
            SELECT 
                Loan_Amount__c,
                Borrower_Status_New__c,
                Account__c,
                Impact_Points__c,
                Bonuses__c,
                Revenue__c,
                Country_New__c
            FROM Loan__c 
            WHERE Id = :loanId
        ];

        // Step 2 - Query monthly balances
        List<Loan_Balance__c> balances = [
            SELECT End_of_Month_Balance__c
            FROM Loan_Balance__c 
            WHERE Loan__c = :loanId
        ];

        // Step 3 - Query the lender account qualification
        Account account = [
            SELECT 
                Id, 
                IP_Qualified__c, 
                FLC_Qualified__c, 
                OI_Qualified__c
            FROM Account 
            WHERE Id = :loan.Account__c
        ];

        // Step 4 - Query ESG standards for bonuses
        ESG_Standard__c esgStandard = [
            SELECT 
                Id, 
                Climate_Smart__c, 
                Gender_Inclusive__c, 
                Youth_Owned__c
            FROM ESG_Standard__c 
            WHERE Account__c = :loan.Account__c
        ];

        // Step 5 - Create incentive record
        Incentive__c incentive = new Incentive__c();
        incentive.Loan__c = loanId;

        // Step 6 - Only calculate if lender is IP qualified
        if (account.IP_Qualified__c) {

            if (account.FLC_Qualified__c) {
                incentive.Max_FLC__c = calculateMaxFLC(loan);
            }

            if (account.OI_Qualified__c) {
                incentive.Max_OI__c = calculateMaxOI(loan, esgStandard);
            }

            incentive.Quaterly_Earnings__c = calculateQuarterlyEarnings(balances);

            upsert incentive;
        }
    }

    // ─────────────────────────────────────
    // CALCULATE MAX FLC
    // ─────────────────────────────────────
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

    // ─────────────────────────────────────
    // CALCULATE MAX OI
    // ─────────────────────────────────────
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

    // ─────────────────────────────────────
    // CALCULATE QUARTERLY EARNINGS
    // ─────────────────────────────────────
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