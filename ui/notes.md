# My commands

```json

sf project generate --name tempproject  

sf org login web --alias mydevorg 

sf project retrieve start \
--metadata ApexClass \
--metadata ApexTrigger \
--metadata LightningComponentBundle \
--target-org mydevorg


sf lightning generate component --name IncentiveSummary --type lwc --output-dir force-app/main/default/lwc

sf apex generate class --name IncentiveSummaryController --output-dir force-app/main/default/classes

sf project deploy start --target-org mydevorg


```


### Paste into Incentive Summary Controller


```java

public with sharing class IncentiveSummaryController {
    
    // Get incentive for a loan
    @AuraEnabled(cacheable=true)
    public static Incentive__c getIncentive(Id loanId) {
        
        List<Incentive__c> incentives = [
            SELECT 
                Id,
                Max_FLC__c,
                Max_OI__c,
                Quarterly_Earnings__c,
                Loan__r.Loan_Amount__c,
                Loan__r.Borrower_Status_New__c,
                Loan__r.Country_New__c,
                Loan__r.Revenue__c
            FROM Incentive__c
            WHERE Loan__c = :loanId
            LIMIT 1
        ];
        
        if (!incentives.isEmpty()) {
            return incentives[0];
        }
        return null;
    }
    
    // Recalculate incentives
    @AuraEnabled
    public static void recalculateIncentives(Id loanId) {
        Set<Id> loanIds = new Set<Id>();
        loanIds.add(loanId);
        IncentiveCalculator.calculateIncentives(loanIds);
    }
}

```


### IncentiveSummary.html

```html

<template>
    <lightning-card title="Loan Incentive Summary" 
                    icon-name="standard:reward">

        <div class="slds-p-around_medium">

            <!-- Loading State -->
            <template if:true={isLoading}>
                <div class="slds-align_absolute-center">
                    <lightning-spinner 
                        alternative-text="Loading" 
                        size="medium">
                    </lightning-spinner>
                </div>
            </template>

            <!-- No Incentive Found -->
            <template if:true={noIncentive}>
                <div class="slds-align_absolute-center slds-p-around_medium">
                    <p>No incentive record found for this loan.</p>
                    <br/>
                    <lightning-button
                        label="Calculate Incentives"
                        variant="brand"
                        onclick={handleCalculate}>
                    </lightning-button>
                </div>
            </template>

            <!-- Incentive Details -->
            <template if:true={incentive}>

                <!-- Loan Details Section -->
                <div class="slds-section slds-is-open">
                    <h3 class="slds-section__title slds-theme_shade">
                        <span class="slds-p-horizontal_small">
                            Loan Details
                        </span>
                    </h3>
                    <div class="slds-grid slds-wrap slds-p-top_small">
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={incentive.Loan__r.Loan_Amount__c}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak">Loan Amount</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <p>{incentive.Loan__r.Borrower_Status_New__c}</p>
                            <p class="slds-text-color_weak">Borrower Type</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <p>{incentive.Loan__r.Country_New__c}</p>
                            <p class="slds-text-color_weak">Country</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={incentive.Loan__r.Revenue__c}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak">SME Revenue</p>
                        </div>
                    </div>
                </div>

                <!-- Incentive Breakdown Section -->
                <div class="slds-section slds-is-open slds-m-top_medium">
                    <h3 class="slds-section__title slds-theme_shade">
                        <span class="slds-p-horizontal_small">
                            Incentive Breakdown
                        </span>
                    </h3>
                    <div class="slds-grid slds-wrap slds-p-top_small">
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={incentive.Max_FLC__c}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak">Max FLC</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={incentive.Max_OI__c}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak">Max OI</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={incentive.Quarterly_Earnings__c}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak">Quarterly Earnings</p>
                        </div>
                        <div class="slds-col slds-size_1-of-2 slds-p-around_small">
                            <lightning-formatted-number
                                value={totalIncentives}
                                format-style="currency"
                                currency-code="USD">
                            </lightning-formatted-number>
                            <p class="slds-text-color_weak 
                                       slds-text-color_success">
                                Total Incentives
                            </p>
                        </div>
                    </div>
                </div>

                <!-- Action Button -->
                <div class="slds-align_absolute-center slds-m-top_medium">
                    <lightning-button
                        label="Recalculate Incentives"
                        variant="brand"
                        onclick={handleCalculate}
                        disabled={isLoading}>
                    </lightning-button>
                </div>

            </template>

        </div>
    </lightning-card>
</template>

```


### IncentiveSummary.js


```javascript

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getIncentive from '@salesforce/apex/IncentiveSummaryController.getIncentive';
import recalculateIncentives from '@salesforce/apex/IncentiveSummaryController.recalculateIncentives';

export default class IncentiveSummary extends LightningElement {
    
    // Gets the current Loan record Id automatically
    @api recordId;
    
    @track isLoading = false;
    @track incentive;
    @track noIncentive = false;

    // Wired result for refresh
    wiredIncentiveResult;

    // Auto fetch incentive when component loads
    @wire(getIncentive, { loanId: '$recordId' })
    wiredIncentive(result) {
        this.wiredIncentiveResult = result;
        if (result.data) {
            this.incentive = result.data;
            this.noIncentive = false;
        } else if (result.error) {
            this.incentive = null;
            this.noIncentive = true;
        }
    }

    // Calculate total incentives
    get totalIncentives() {
        if (!this.incentive) return 0;
        return (
            (this.incentive.Max_FLC__c || 0) +
            (this.incentive.Max_OI__c || 0) +
            (this.incentive.Quarterly_Earnings__c || 0)
        );
    }

    // Handle recalculate button click
    handleCalculate() {
        this.isLoading = true;
        
        recalculateIncentives({ loanId: this.recordId })
            .then(() => {
                // Refresh the incentive data
                return refreshApex(this.wiredIncentiveResult);
            })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!',
                        message: 'Incentives calculated successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}
```


### incentiveSummary.js-meta.xml

```xml

<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__RecordPage">
            <objects>
                <object>Loan__c</object>
            </objects>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>


```


Go to any Loan record
→ Click ⚙️ gear icon on the page
→ Edit Page
→ Search "IncentiveSummary" in left panel
→ Drag it onto the page
→ Save
→ Activate