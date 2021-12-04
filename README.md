# Confidential Clean Room Services for DEPA
### Architecture Guidelines
### Version 1.0

## Summary

Confidential clean rooms are a new privacy construct in DEPA which enforce that data is only used in accordance with the data principal’s consent. This document proposes guidelines for enabling data processing services to be hosted in confidential clean room environments. 

## Glossary

| | |
|----------------|--------------------------------------------------|
| DEPA | Data Empowerment and Protection Architecture |
| DC | Data Consumer |
| FIU | Financial Information User |
| FIP | Financial Information Provider |
| CM | Consent Manager |
| AA | Account Aggregator |
| TEE | Trusted Execution Environment |
| CCR | Confidential Clean Room |
| CRS | Clean Room Service |
| CRMS | Clean Room Micro-service |

## DEPA, Privacy and Compliance

The Data Empowerment and Protection Architecture or DEPA enables sharing personal data held by one or more data providers with data consumers with the consent of the data principal. DEPA introduces the notion of a consent manager that is responsible for interfacing with data principals, obtaining informed consent to retrieve their data from data providers, and to share that data securely with data consumers. The Account Aggregator, OCEN and the recently launched Unified Health Interface are the first instances of DEPA. The Account Aggregator and OCEN enable scenarios such as flow-based lending, where a borrower (an individual or an MSME business) can obtain uncollateralized credit based on cash-flow information such as bank statements and GST. 

As it stands, there are a few challenges with DEPA. The first is the potential for data misuse. With DEPA, any data consumer can easily obtain personal data and subsequently misuse the data in violation of consent. The risk of misuse is significantly higher in frameworks like OCEN where data is exposed to multiple data consumers. Today, there is no mechanism to enforce that all data consumers process data strictly in accordance with declarations made by the data consumer in the consent request e.g., for the purpose and lifetime defined in the consent request. To some extent, this problem is addressed by mandating compliance and audit, which limits participation to a select set of regulated entities. As DEPA evolves and number of data providers and consumers, and is used for sharing different kinds of data, concerns regarding data misuse will only grow.

A second related challenge is data over-collection. Using the consent mechanism provided by DEPA, it is easy for a data consumer to ask for more data than what is strictly required for the service being offered to the data principal. It is envisaged that data consumers will be restricted to using only one amongst a set of pre-defined consent templates, but it is challenging to define and enforce the use of such templates. 

Another challenge is lack of access to high quality training data to train better models. Access to training data is challenging for multiple reasons. First and foremost, there are no incentives for data principals to share data for training since it doesn't directly benefit them. Secondly, training requires large amounts of data to be collected and labelled over a long period of time, all of which significantly increases privacy risks. 

## Confidential Clean Rooms

Confidential clean rooms are a new privacy construct in DEPA designed to address these concerns. A confidential clean room is a secure, isolated execution environment where sensitive information from one or more data providers can be processed with technical security and privacy guarantees. Confidential clean rooms can be set up and operated by data consumers, their subsidiaries, technology service providers, or independent third parties. 

Clean rooms invert the computation model in DEPA. Instead of receiving raw sensitive information, data consumers deploy their workloads/services in clean rooms. Subsequently, requests to process data are sent to the clean rooms. Requests contain encrypted data from one or more data providers along with consent artifacts. Clean rooms decrypt and process this data in accordance with the data principal’s consent and a data usage policy which defines valid outcomes that can be released to the data consumer. Making data usage policy and its enforcement explicit in the service architecture address data leakage challenges and simplifies the process of proving compliance to regulators and/or external auditors, which in turn can help reduce the over cost of operationalizing compliant services. 

The clean room service architecture guidelines defined in this document outlines an approach for architecting services to ensure that data is processed in accordance with consent and a data usage policy *while minimizing trust in the data consumer and their infrastructure*. The guidelines are broadly based on the principle of *minimal trust* i.e., ensure that the service continues to process data according to consent and data usage policies even if components in the service are breached or individuals within the data consumer organization are compromised. 

Trust in service components is minimized by decoupling the core business logic of services from operations such as auditing and management of secrets and hosting the business logic in a *sandboxed environment *where all ingress and egress communication is monitored and checked for violations of consent and data usage policy. Trust in entities such as service administrators may be minimized using strict access control augmented with technologies such as confidential computing. 

## Clean Room Service Architecture
A clean room service (CRS) is composed of one-or more clean room microservices (CRMS) potentially hosted by different organizations. 

Each CRMS consists of multiple pods, each hosting one or more business logic containers. These containers expose their functionality via one or more HTTP endpoints.  

Each CRS has one or more HTTP endpoints that serve as entry points for receiving data processing requests. For example, in the AA scenario, the FIU sends encrypted data received from the account aggregator along with any additional data to one of these entry points of a CRS for processing. 

Each CRS should service requests only for a single purpose code/product category to maintain separation of data obtained for different purposes. 

Business logic containers deployed in CRMS should be signed (using a service like Notary). 

Business logic containers deployed in CRMS should be stateless i.e., they receive requests and generate responses without persisting inputs or intermediate results. Any access to persistent storage (e.g., a ledger, message queue, or database) from within the CRS must be limited to carefully audited sidecar containers that proxy access to storage.

Each CRMS may be supported by a control plane consisting of services such as an identity service, key management service, a ledger service, and a container registry. 

## Data Usage Policy

A CRS is associated with a data usage policy, a set of machine-enforceable rules that govern all data that is processed and generated by the CRS. 

The CRS should be configured to check the data usage policy on every ingress and egress of data from the CRS.  

The policy must ensure that any data obtained through an account aggregator is processed only if it is associated with a valid consent artifact signed by an account aggregator. 

The policy must ensure that any data obtained through an account aggregator is processed only if it has been signed by a valid FIP. 

The policy must ensure that any response generated by the CRS should not contain any personal data. The response should only contain the outcome required by the FIU to provide the data principal with the expected service. For example, the policy for a loan processing service must check that the response generated by the service should be a valid loan offer and should not contain any information used to evaluate the loan application. 

The policy may be expressed in a language such as Rego and checked by a sidecar container (such as the Open Policy Agent). 

## Sandbox

Each CRMS hosts its business logic containers in a sandboxed environment, which monitors communication to and from the business logic containers and enforce compliance with consent and data usage policy. 

There are many ways of implementing a sandbox. For example, a sandbox may be implemented using a network proxy (e.g., [envoy](https://www.envoyproxy.io/)) deployed in every CRMS. The proxy is configured to intercept all network I/O to and from business logic containers, and redirect the traffic to a policy engine (such as [Open Policy Agent](https://www.openpolicyagent.org/)) for checking that all I/O is compliant with the data usage policy (See Section 11).

The proxy should ensure that all communication between microservices within the clean room uses mutually authenticated TLS. 

The proxy should limit any unexpected traffic to and from business logic containers. For example, the proxy may only permit HTTP traffic, and drop all non-HTTP TCP communications. 

Each CRMS should be configured to run business logic containers should with the least set of capabilities required to execute their tasks. For example, business logic containers should run as non-root users and should not get capabilities such as the ability to mount file systems, open non-TCP sockets, or any other capability that may be used to exfiltrate data without going through the proxy. 

## Identity and Access Control

Each CRMS should be assigned an identity (e.g., an X.509) by a trustworthy identity service. 

Issuance of the identity should be based on assessing evidence from the service deployment. Evidence may include the set of containers deployed and their configuration. 

The identity issuing service should maintain a transparency log that records all evidence that it receives and identities that it issues. 

Each CRMS should use its identity to authenticate and authorize other CRMS. 

In case CRMS within a CRS are deployed across organizations, communication between CRMS should be secured e.g., by federating across identity providers. 

## Key Management

A CRS may use a key management service for generating, storing, and managing encryption keys e.g., key shares for decrypting data received from FIPs through the AA. 

Access to keys that encrypt sensitive customer data must be restricted only to services within the clean room. No individuals including service administrators should have access to the keys. 

## Audit

Each CRMS must maintain comprehensive and tamper-proof logs of all transactions for audit and dispute resolution purposes. 

All data in the log must be encrypted with keys managed by a secure key management service. 

Implementations of the log must be able to detect and potentially tolerate data loss and tampering attacks e.g., through a combination of replication and cryptographic protection such as Merkle trees. 

Access to the log must be restricted to CRMS in the CRS. 

The CRMS should support an API for retrieving data from the log for audit and/or dispute resolution purposes. Any access to this API should require appropriate authorization e.g., a separate consent from the data principal or a signed request from an external auditor/dispute resolution body. 
