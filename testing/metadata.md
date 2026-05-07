# Metadata
Click → New Custom Metadata Type

Fill in:
- Label: Incentive Config
- Plural Label: Incentive Configs
- Object Name: Incentive_Config  ← auto fills

Click → Save

Step 4 — Add The Attribute Map Field
Scroll down to → Custom Fields
Click → New

Select → Long Text Area
Click → Next

Fill in:
- Field Label: Attribute Map
- Field Name: Attribute_Map  ← auto fills
- Length: 10000

Click → Next → Next → Save

Step 5 — Create The Record
Click → Manage Incentive Configs (top right button)
Click → New

Fill in:
- Label: Incentive Calculator Config
- Name: Incentive_Calculator_Config  ← auto fills (MUST match code exactly)

Attribute Map field → paste this JSON:

```json

{
    "baseFactor": 0.04,
    "factorIncrement": 0.01,
    "oILoanAmountThreshold": 15000,
    "oIRevenueThreshold": 1000000,
    "baseOIConstant": 0.0015,
    "oILoanBasImpactConstant": 0.005,
    "eSGYouthOwnedBonus": 1000,
    "eSGClimateSmartBonus": 2000,
    "eSGGenderInclusiveBonus": 1500,
    "countryAdjustment": 1.1,
    "balanceOIConstant": 0.06,
    "balanceFLCConstant": 0.055
}
```

code for handling constants

```java

public class IncentiveCalculatorConstants {
    
    // Name of the custom metadata record
    public static String INCENTIVE_CALCULATOR_CONFIG = 'Incentive_Calculator_Config';
    
    public static Map<String, Double> loadConstants() {
        
        Map<String, Double> constantValuesMap = new Map<String, Double>();
        String constantValuesObject;
        
        // Query the custom metadata record
        for (Incentive_Config__mdt incentiveConfig : [
            SELECT Attribute_Map__c
            FROM Incentive_Config__mdt
            WHERE DeveloperName = :INCENTIVE_CALCULATOR_CONFIG
            LIMIT 1
        ]) {
            constantValuesObject = incentiveConfig.Attribute_Map__c;
        }
        
        // Deserialize the JSON into a map
        Map<String, Object> constantValues = (Map<String, Object>) 
            JSON.deserializeUntyped(constantValuesObject);
        
        // FLC Constants
        constantValuesMap.put('baseFactor',
            (Double) constantValues.get('baseFactor'));          // 0.04
            
        constantValuesMap.put('factorIncrement',
            (Double) constantValues.get('factorIncrement'));     // 0.01

        // OI Constants
        constantValuesMap.put('oILoanAmountThreshold',
            (Double) constantValues.get('oILoanAmountThreshold')); // 15000
            
        constantValuesMap.put('oIRevenueThreshold',
            (Double) constantValues.get('oIRevenueThreshold'));    // 1000000
            
        constantValuesMap.put('baseOIConstant',
            (Double) constantValues.get('baseOIConstant'));        // 0.0015
            
        constantValuesMap.put('oILoanBasImpactConstant',
            (Double) constantValues.get('oILoanBasImpactConstant')); // 0.005

        // ESG Bonus Constants
        constantValuesMap.put('eSGYouthOwnedBonus',
            (Double) constantValues.get('eSGYouthOwnedBonus'));    // 1000
            
        constantValuesMap.put('eSGClimateSmartBonus',
            (Double) constantValues.get('eSGClimateSmartBonus')); // 2000
            
        constantValuesMap.put('eSGGenderInclusiveBonus',
            (Double) constantValues.get('eSGGenderInclusiveBonus')); // 1500

        // Country Adjustment
        constantValuesMap.put('countryAdjustment',
            (Double) constantValues.get('countryAdjustment'));     // 1.1

        // Quarterly Earnings Constants
        constantValuesMap.put('balanceOIConstant',
            (Double) constantValues.get('balanceOIConstant'));     // 0.06
            
        constantValuesMap.put('balanceFLCConstant',
            (Double) constantValues.get('balanceFLCConstant'));    // 0.055

        return constantValuesMap;
    }
}
```