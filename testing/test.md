```java

@isTest
public class IncentiveCalculatorTest {
    
    @TestSetup
    static void setupTestData() {
        
        // Create Account (Financial Institution)
        Account account = new Account(
            Name = 'Test Bank Kenya',
            IP_Qualified__c = true,
            FLC_Qualified__c = true,
            OI_Qualified__c = true
        );
        insert account;
        
        // Create ESG Standard linked to Account
        ESG_Standard__c esg = new ESG_Standard__c(
            Account__c = account.Id,
            Youth_Owned__c = true,
            Climate_Smart__c = true,
            Gender_Inclusive__c = true
        );
        insert esg;
        
        // Create Loan linked to Account
        Loan__c loan = new Loan__c(
            Account__c = account.Id,
            Loan_Amount__c = 50000,
            Revenue__c = 2000000,
            Country_New__c = 'Kenya',
            Borrower_Status_New__c = 'Returning',
            Impact_Points__c = 5
        );
        insert loan;
        
        // Create Loan Balances
        List<Loan_Balance__c> balances = new List<Loan_Balance__c>();
        for (Integer i = 0; i < 3; i++) {
            balances.add(new Loan_Balance__c(
                Loan__c = loan.Id,
                End_of_Month_Balance__c = 100000
            ));
        }
        insert balances;
    }


    @isTest
    static void testCalculateIncentives() {
        
        // Get loan created in setup
        Loan__c loan = [SELECT Id FROM Loan__c LIMIT 1];
        
        // Build Set<Id> — matches new method signature
        Set<Id> loanIds = new Set<Id>();
        loanIds.add(loan.Id);
        
        Test.startTest();
        IncentiveCalculator.calculateIncentives(loanIds);
        Test.stopTest();
        
        // Verify incentive was created
        List<Incentive__c> incentives = [
            SELECT Id, Max_FLC__c, Max_OI__c, Quarterly_Earnings__c
            FROM Incentive__c
            WHERE Loan__c = :loan.Id
        ];
        
        System.assertEquals(1, incentives.size(), 
            'One incentive should be created');
        System.assertNotEquals(0, incentives[0].Max_FLC__c, 
            'FLC should not be zero');
        System.assertNotEquals(0, incentives[0].Max_OI__c, 
            'OI should not be zero');
        System.assertNotEquals(0, incentives[0].Quarterly_Earnings__c, 
            'Quarterly earnings should not be zero');
    }

    @isTest
    static void testCalculateIncentivesMultipleLoans() {
        
        Account account = [SELECT Id FROM Account LIMIT 1];
        
        // Create 3 more loans
        List<Loan__c> loans = new List<Loan__c>();
        for (Integer i = 0; i < 3; i++) {
            loans.add(new Loan__c(
                Account__c = account.Id,
                Loan_Amount__c = 50000 + (i * 10000),
                Revenue__c = 2000000,
                Country_New__c = 'Kenya',
                Borrower_Status_New__c = 'Returning',
                Impact_Points__c = 3
            ));
        }
        insert loans;
        
        // Build Set<Id> with all loan ids
        Set<Id> loanIds = new Set<Id>();
        for (Loan__c loan : loans) {
            loanIds.add(loan.Id);
        }
        
        Test.startTest();
        IncentiveCalculator.calculateIncentives(loanIds);
        Test.stopTest();
        
        // All 3 should have incentives
        List<Incentive__c> incentives = [
            SELECT Id FROM Incentive__c
            WHERE Loan__c IN :loanIds
        ];
        
        System.assertEquals(3, incentives.size(), 
            '3 incentives should be created for 3 loans');
    }

    @isTest
    static void testCalculateMaxFLC() {
        
        Loan__c loan = [
            SELECT Id, Loan_Amount__c, Borrower_Status_New__c, Impact_Points__c
            FROM Loan__c 
            LIMIT 1
        ];
        
        Test.startTest();
        Decimal flc = IncentiveCalculator.calculateMaxFLC(loan);
        Test.stopTest();
        
        // 50000 × (0.04 + 0.01 + 5×0.005) = 50000 × 0.075 = 3750
        System.assertEquals(3750, flc, 'FLC should be 3750');
    }

    
    @isTest
    static void testCalculateMaxFLCNullAmount() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = null,
            Borrower_Status_New__c = 'Returning'
        );
        
        Test.startTest();
        Decimal flc = IncentiveCalculator.calculateMaxFLC(loan);
        Test.stopTest();
        
        System.assertEquals(0, flc, 
            'FLC should be 0 for null amount');
    }

    
    @isTest
    static void testCalculateMaxOI() {
        
        Loan__c loan = [
            SELECT Id, Loan_Amount__c, Revenue__c, 
                   Country_New__c, Impact_Points__c, Account__c
            FROM Loan__c 
            LIMIT 1
        ];
        
        ESG_Standard__c esg = [
            SELECT Id, Youth_Owned__c, Climate_Smart__c, Gender_Inclusive__c
            FROM ESG_Standard__c 
            LIMIT 1
        ];
        
        Test.startTest();
        Decimal oi = IncentiveCalculator.calculateMaxOI(loan, esg);
        Test.stopTest();
        
        System.assertNotEquals(0, oi, 'OI should not be zero');
    }


    @isTest
    static void testCalculateMaxOIBelowThreshold() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 5000, // Below 15000 threshold
            Revenue__c = 2000000,
            Country_New__c = 'Kenya'
        );
        
        ESG_Standard__c esg = new ESG_Standard__c(
            Youth_Owned__c = false,
            Climate_Smart__c = false,
            Gender_Inclusive__c = false
        );
        
        Test.startTest();
        Decimal oi = IncentiveCalculator.calculateMaxOI(loan, esg);
        Test.stopTest();
        
        System.assertEquals(0, oi, 
            'OI should be 0 for loans below threshold');
    }


    @isTest
    static void testNoESGRecord() {
        
        // Create account with no ESG record
        Account account = new Account(
            Name = 'No ESG Bank',
            IP_Qualified__c = true,
            FLC_Qualified__c = true,
            OI_Qualified__c = true
        );
        insert account;
        
        Loan__c loan = new Loan__c(
            Account__c = account.Id,
            Loan_Amount__c = 50000,
            Revenue__c = 2000000,
            Country_New__c = 'Kenya',
            Borrower_Status_New__c = 'New'
        );
        insert loan;
        
        // Build Set<Id>
        Set<Id> loanIds = new Set<Id>();
        loanIds.add(loan.Id);
        
        Test.startTest();
        // Should not crash even without ESG record
        IncentiveCalculator.calculateIncentives(loanIds);
        Test.stopTest();
        
        List<Incentive__c> incentives = [
            SELECT Id FROM Incentive__c
            WHERE Loan__c = :loan.Id
        ];
        
        System.assertEquals(1, incentives.size(), 
            'Incentive should still be created without ESG');
    }

    @isTest
    static void testCalculateQuarterlyEarnings() {
        
        List<Loan_Balance__c> balances = [
            SELECT Id, End_of_Month_Balance__c
            FROM Loan_Balance__c
        ];
        
        Test.startTest();
        Decimal earnings = IncentiveCalculator.calculateQuarterlyEarnings(balances);
        Test.stopTest();
        
        // 3 balances × 100000 × (0.06 + 0.055) = 34500
        System.assertEquals(34500, earnings, 
            'Quarterly earnings should be 34500');
    }

    @isTest
    static void testCalculateQuarterlyEarningsEmpty() {
        
        List<Loan_Balance__c> balances = new List<Loan_Balance__c>();
        
        Test.startTest();
        Decimal earnings = IncentiveCalculator.calculateQuarterlyEarnings(balances);
        Test.stopTest();
        
        System.assertEquals(0, earnings, 
            'Earnings should be 0 for empty balances');
    }


    @isTest
    static void testAccountNotQualified() {
        
        Account account = new Account(
            Name = 'Unqualified Bank',
            IP_Qualified__c = false,
            FLC_Qualified__c = false,
            OI_Qualified__c = false
        );
        insert account;
        
        ESG_Standard__c esg = new ESG_Standard__c(
            Account__c = account.Id,
            Youth_Owned__c = false,
            Climate_Smart__c = false,
            Gender_Inclusive__c = false
        );
        insert esg;
        
        Loan__c loan = new Loan__c(
            Account__c = account.Id,
            Loan_Amount__c = 50000,
            Revenue__c = 2000000,
            Country_New__c = 'Kenya',
            Borrower_Status_New__c = 'Returning'
        );
        insert loan;
        
        Set<Id> loanIds = new Set<Id>();
        loanIds.add(loan.Id);
        
        Test.startTest();
        IncentiveCalculator.calculateIncentives(loanIds);
        Test.stopTest();
        
        // No incentive should be created
        List<Incentive__c> incentives = [
            SELECT Id FROM Incentive__c
            WHERE Loan__c = :loan.Id
        ];
        
        System.assertEquals(0, incentives.size(), 
            'No incentive for unqualified account');
    }

    @isTest
    static void testTrigger() {
        
        Account account = [SELECT Id FROM Account LIMIT 1];
        
        Loan__c loan = new Loan__c(
            Account__c = account.Id,
            Loan_Amount__c = 75000,
            Revenue__c = 3000000,
            Country_New__c = 'Tanzania',
            Borrower_Status_New__c = 'Returning',
            Impact_Points__c = 2
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        List<Incentive__c> incentives = [
            SELECT Id, Max_FLC__c, Max_OI__c
            FROM Incentive__c
            WHERE Loan__c = :loan.Id
        ];
        
        System.assertEquals(1, incentives.size(), 
            'Trigger should create one incentive');
    }


    //@isTest
    //static void testBatch() {
        
        //Test.startTest();
        //IncentiveCalculatorBatch batch = new IncentiveCalculatorBatch();
        //Database.executeBatch(batch, 200);
        //Test.stopTest();
        
        //List<Incentive__c> incentives = [SELECT Id FROM Incentive__c];
        //System.assertNotEquals(0, incentives.size(), 
            //'Batch should create incentives');
    
}
```