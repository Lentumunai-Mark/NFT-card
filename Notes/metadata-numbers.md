Step 1 — Create Custom Metadata Type:
Setup → Custom Metadata Types → New

Label: Loan Risk Config
Object Name: Loan_Risk_Config
→ Save

Step 2 — Add Fields:
New Field → Number
Label: High Risk Threshold
Field Name: High_Risk_Threshold
→ Save

New Field → Number
Label: Medium Risk Min
Field Name: Medium_Risk_Min
→ Save

New Field → Number
Label: Medium Risk Max
Field Name: Medium_Risk_Max
→ Save

Step 3 — Create The Record:
Manage Loan Risk Configs → New

Label: Loan Risk Config
Name: Loan_Risk_Config   ← must match code exactly

High Risk Threshold: 100000
Medium Risk Min: 50000
Medium Risk Max: 100000

```java


public class LoanRiskConstants {

    //declare developer name in a const always
    public static String LOAN_RISK_CONFIG = 'Loan_Risk_Config';
    
    public static Map<String, Decimal> loadConstants() {
        
        Map<String, Decimal> constants = new Map<String, Decimal>();
        
        for (Loan_Risk_Config__mdt config : [
            SELECT 
                High_Risk_Threshold__c,
                Medium_Risk_Min__c,
                Medium_Risk_Max__c
            FROM Loan_Risk_Config__mdt
            WHERE DeveloperName = :LOAN_RISK_CONFIG
            LIMIT 1
        ]) {
            constants.put('highRiskThreshold', config.High_Risk_Threshold__c);
            constants.put('mediumRiskMin', config.Medium_Risk_Min__c);
            constants.put('mediumRiskMax', config.Medium_Risk_Max__c);
        }
        
        return constants;
    }
}

```
## Handler Class

```java

public class LoanRiskHandler {
    
    // Load constants once
    public static Map<String, Decimal> riskConstants = 
        LoanRiskConstants.loadConstants();
    
    public static void assignRiskLevel(List<Loan__c> loans) {
        
        // Get thresholds from metadata
        Decimal highThreshold = riskConstants.get('highRiskThreshold');
        Decimal mediumMin = riskConstants.get('mediumRiskMin');
        Decimal mediumMax = riskConstants.get('mediumRiskMax');
        
        for (Loan__c loan : loans) {
            
            if (loan.Loan_Amount__c == null) {
                continue; // skip null amounts
            }
            
            // Step 1 - Assign Risk Level from metadata thresholds
            if (loan.Loan_Amount__c > highThreshold) {
                loan.Risk_Level__c = 'High';
                
            } else if (loan.Loan_Amount__c >= mediumMin && 
                       loan.Loan_Amount__c <= mediumMax) {
                loan.Risk_Level__c = 'Medium';
                
            } else {
                loan.Risk_Level__c = 'Low';
            }
            
            // Step 2 - Set Status based on Risk
            if (loan.Risk_Level__c == 'High') {
                loan.Status__c = 'Pending Review';
            } else {
                loan.Status__c = 'Approved';
            }
        }
    }
}

```

## trigger

```java

trigger LoanRiskTrigger on Loan__c (before insert, before update) {
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            LoanRiskHandler.assignRiskLevel(Trigger.new);
        }
    }
}
```


additional stuff


Loan_Amount__c     → Currency (already exists)
Risk_Level__c      → Picklist (High, Medium, Low)
Status__c          → Picklist (Pending Review, Approved)


```java

@isTest
public class LoanRiskHandlerTest {

    // ─────────────────────────────────────
    // TEST 1 — High Risk Loan
    // ─────────────────────────────────────
    @isTest
    static void testHighRiskLoan() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 150000 // Above 100,000
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('High', result.Risk_Level__c, 
            'Risk should be High');
        System.assertEquals('Pending Review', result.Status__c, 
            'Status should be Pending Review');
    }

    // ─────────────────────────────────────
    // TEST 2 — Medium Risk Loan
    // ─────────────────────────────────────
    @isTest
    static void testMediumRiskLoan() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 75000 // Between 50,000 - 100,000
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('Medium', result.Risk_Level__c, 
            'Risk should be Medium');
        System.assertEquals('Approved', result.Status__c, 
            'Status should be Approved');
    }

    // ─────────────────────────────────────
    // TEST 3 — Low Risk Loan
    // ─────────────────────────────────────
    @isTest
    static void testLowRiskLoan() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 25000 // Below 50,000
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('Low', result.Risk_Level__c, 
            'Risk should be Low');
        System.assertEquals('Approved', result.Status__c, 
            'Status should be Approved');
    }

    // ─────────────────────────────────────
    // TEST 4 — Boundary: Exactly 100,000
    // ─────────────────────────────────────
    @isTest
    static void testBoundaryHundredThousand() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 100000 // Exactly at boundary
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('Medium', result.Risk_Level__c, 
            'Exactly 100,000 should be Medium');
        System.assertEquals('Approved', result.Status__c, 
            'Status should be Approved');
    }

    // ─────────────────────────────────────
    // TEST 5 — Boundary: Exactly 50,000
    // ─────────────────────────────────────
    @isTest
    static void testBoundaryFiftyThousand() {
        
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 50000 // Exactly at boundary
        );
        
        Test.startTest();
        insert loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('Medium', result.Risk_Level__c, 
            'Exactly 50,000 should be Medium');
        System.assertEquals('Approved', result.Status__c, 
            'Status should be Approved');
    }

    // ─────────────────────────────────────
    // TEST 6 — Update Loan Amount
    // ─────────────────────────────────────
    @isTest
    static void testUpdateLoanAmount() {
        
        // Start as low risk
        Loan__c loan = new Loan__c(
            Loan_Amount__c = 25000
        );
        insert loan;
        
        // Update to high risk
        loan.Loan_Amount__c = 200000;
        
        Test.startTest();
        update loan;
        Test.stopTest();
        
        Loan__c result = [
            SELECT Risk_Level__c, Status__c 
            FROM Loan__c 
            WHERE Id = :loan.Id
        ];
        
        System.assertEquals('High', result.Risk_Level__c, 
            'Risk should update to High');
        System.assertEquals('Pending Review', result.Status__c, 
            'Status should update to Pending Review');
    }

    // ─────────────────────────────────────
    // TEST 7 — Bulk Loans
    // ─────────────────────────────────────
    @isTest
    static void testBulkLoans() {
        
        List<Loan__c> loans = new List<Loan__c>();
        
        // Create 10 high risk
        for (Integer i = 0; i < 10; i++) {
            loans.add(new Loan__c(Loan_Amount__c = 150000));
        }
        
        // Create 10 medium risk
        for (Integer i = 0; i < 10; i++) {
            loans.add(new Loan__c(Loan_Amount__c = 75000));
        }
        
        // Create 10 low risk
        for (Integer i = 0; i < 10; i++) {
            loans.add(new Loan__c(Loan_Amount__c = 25000));
        }
        
        Test.startTest();
        insert loans;
        Test.stopTest();
        
        // Check counts
        System.assertEquals(10, 
            [SELECT COUNT() FROM Loan__c WHERE Risk_Level__c = 'High'],
            '10 high risk loans');
        System.assertEquals(10, 
            [SELECT COUNT() FROM Loan__c WHERE Risk_Level__c = 'Medium'],
            '10 medium risk loans');
        System.assertEquals(10, 
            [SELECT COUNT() FROM Loan__c WHERE Risk_Level__c = 'Low'],
            '10 low risk loans');
    }
}
```