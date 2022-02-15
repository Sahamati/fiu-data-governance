import datetime
import json
import os
import random

workingDirectory = os.path.dirname(os.path.realpath(__file__))
output_json_file = "transactions.json"

name = "John Doe"
address = "Mi Casa, New Delhi, India"
dob = "1989-10-16"
mobile = "9876543210"
landline = "0117654321"
email = "john@doe.com"
pan = "AGHDS9898T"

num_transactions = 10
txn_type = ["CREDIT", "DEBIT"]
txn_mode = ["CASH", "ATM", "CARD", "UPI", "OTHERS"]
curr_balance = 500000
txn_narration = ["YUM Restaurant", "Self", "Flight Ticket", "Train Ticket", 
                 "XYZ Hospital", "ABC Pharmacy", "INOX", "Shopping", "Transfer"]

year = 2021
month = 1
date = 1

f = open(os.path.join(workingDirectory, 'data', output_json_file), "w")
# Write summary.
data = {
  "type": "SAVINGS",
  "maskedAccNumber": "********1234",
  "version": "1.1.2",
  "linkedAccRef": "ref74343876876513",
  "Profile": {
    "Holders": {
      "type": "single",
      "Holder": [{
      "name": name,
      "dob": dob,
      "mobile": mobile,
      "nominee": "REGISTERED",
      "landline": landline,
      "address": address,
      "email": email,
      "pan":pan,
      "ckycConpliance": "true"
      }]
    }
  },
  "Summary": {
    "currentBalance": curr_balance,
    "currency": "INR",
    "exchangeRate": "1",
    "balanceDataTime": "2021-03-11T11:39:57.153Z",
    "type": "SAVINGS",
    "branch": "Hauz Khas",
    "facility": "OD",
    "ifscCode": "SBIN00001",
    "micrCode": "SBIN00002",
    "openingDate": "2001-10-16",
    "currentODLimit": "1024",
    "drawingLimit": "4096",
    "status": "active",
    "Pending": [ {
      "transactionType": "CREDIT",
      "amount": "25000"
    },
    {
      "transactionType": "DEBIT",
      "amount": "10000"
    }]
  },
  "Transactions": {
    "startDate": "2021-01-01",
    "endData": "2021-01-31",
    "Transaction": []
  }
}

for i in range(num_transactions):
    amount = random.randrange(1000, 10000)
    txn = random.choice(txn_type)
    if txn == "CREDIT":
        curr_balance += amount
    else:
        curr_balance -= amount
    if i > 0 and i%4 == 0:
        date += 1
    data['Transactions']['Transaction'].append({
        "type": txn,
        "mode": random.choice(txn_mode),
        "amount": amount,
        "currentBalance": curr_balance,
        "transactionTimestamp": datetime.datetime(year, month, date, random.randrange(10, 19), 
                                random.randrange(0, 59), random.randrange(0, 59), random.randrange(0, 1000)).__str__(),
        "valueDate": datetime.date(year, month, date).__str__(),
        "txnID": random.randrange(123456, 987654),
        "narration": random.choice(txn_narration),
        "reference": random.randrange(12345, 98765)
    })

data['Summary']['currentBalance'] = curr_balance

f.write(json.dumps(data, indent=2))
f.close()
