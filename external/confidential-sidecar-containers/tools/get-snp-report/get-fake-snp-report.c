/* Copyright (c) Microsoft Corporation.
   Licensed under the MIT License. */

#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>

#include "snp-psp.h"

#define PRINT_VAL(ptr, field) printBytes(#field, (const uint8_t *)&(ptr->field), sizeof(ptr->field), true)
#define PRINT_BYTES(ptr, field) printBytes(#field, (const uint8_t *)&(ptr->field), sizeof(ptr->field), false)

// Helper functions
uint8_t* decodeHexString(char *hexstring)
{   
    size_t len = strlen(hexstring);
    uint8_t *byte_array = (uint8_t*) malloc(strlen(hexstring)*sizeof(uint8_t));
    
    for (size_t i = 0; i < len; i+=2) {        
        sscanf(hexstring, "%2hhx", &byte_array[i/2]);
        hexstring += 2;        
    }

    return byte_array;
}

char* encodeHexToString(uint8_t byte_array[], size_t len)
{    
    char* hexstring = (char*) malloc((2*len+1)*sizeof(char));

    for (size_t i = 0; i < len; i++)       
        sprintf(&hexstring[i*2], "%02x", byte_array[i]);                    
    
    hexstring[2*len] = '\0'; // string padding character    
    return hexstring;
}

void printBytes(const char *desc, const uint8_t *data, size_t len, bool swap)
{
    fprintf(stderr, "  %s: ", desc);
    int padding = 20 - strlen(desc);
    if (padding < 0)
        padding = 0;
    for (int count = 0; count < padding; count++)
        putchar(' ');

    for (size_t pos = 0; pos < len; pos++) {
        fprintf(stderr, "%02x", data[swap ? len - pos - 1 : pos]);
        if (pos % 32 == 31)
            printf("\n                        ");
        else if (pos % 16 == 15)
            putchar(' ');
    }
    fprintf(stderr, "\n");
}

void printReport(const snp_attestation_report *r)
{    
    PRINT_VAL(r, version);
    PRINT_VAL(r, guest_svn);
    PRINT_VAL(r, policy);
    PRINT_VAL(r, family_id);
    PRINT_VAL(r, image_id);
    PRINT_VAL(r, vmpl);
    PRINT_VAL(r, signature_algo);
    PRINT_BYTES(r, platform_version);
    PRINT_BYTES(r, platform_info);
    PRINT_VAL(r, author_key_en);
    PRINT_VAL(r, reserved1);
    PRINT_BYTES(r, report_data);
    PRINT_BYTES(r, measurement);
    PRINT_BYTES(r, host_data);
    PRINT_BYTES(r, id_key_digest);
    PRINT_BYTES(r, author_key_digest);
    PRINT_BYTES(r, report_id);
    PRINT_BYTES(r, report_id_ma);
    PRINT_VAL(r, reported_tcb);
    PRINT_BYTES(r, reserved2);
    PRINT_BYTES(r, chip_id);
    PRINT_BYTES(r, reserved3);
    PRINT_BYTES(r, signature);
}


bool fetchAttestationReport(char report_data_hexstring[], char host_data_hexstring[], void **snp_report)
{
 
    snp_attestation_report attestation_report;

    uint8_t *default_report = decodeHexString("01000000010000001f00030000000000010000000000000000000000000000000200000000000000000000000000000000000000010000000000000000000028010000000000000000000000000000007ab000a323b3c873f5b81bbe584e7c1a26bcf40dc27e00f8e0d144b1ed2d14f10000000000000000000000000000000000000000000000000000000000000000e29af700e85b39996fa38226d2804b78cad746ffef4477360a61b47874bdecd640f9d32f5ff64a55baad3c545484d9ed28603a3ea835a83bd688b0ec1dcb36b6b8c22412e5b63115b75db8628b989bc598c475ca5f7683e8d351e7e789a1baff19041750567161ad52bf0d152bd76d7c6f313d0a0fd72d0089692c18f521155800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040aea62690b08eb6d680392c9a9b3db56a9b3cc44083b9da31fb88bcfc493407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000028000000000000000000000000000000000000000000000000e6c86796cd44b0bc6b7c0d4fdab33e2807e14b5fc4538b3750921169d97bcf4447c7d3ab2a7c25f74c1641e2885c1011d025cc536f5c9a2504713136c7877f480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003131c0f3e7be5c6e400f22404596e1874381e99d03de45ef8b97eee0a0fa93a4911550330343f14dddbbd6c0db83744f000000000000000000000000000000000000000000000000db07c83c5e6162c2387f3b76cd547672657f6a5df99df98efee7c15349320d83e086c5003ec43050a9b18d1c39dedc340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    
    memcpy((uint8_t*)&attestation_report, default_report, sizeof(snp_attestation_report));
    memset(attestation_report.report_data, 0 , 64);
    memset(attestation_report.host_data, 0 , 32);
    
    // MAA expects a SHA-256. So we use 32 bytes as size instead of msg_report_in.report_data
    // the report data is passed as a hexstring which needs to be decoded into an array of 
    // unsigned bytes

    uint8_t *reportData = decodeHexString(report_data_hexstring);     
    memcpy(attestation_report.report_data, reportData , strlen(report_data_hexstring)/2);

    uint8_t *hostData = decodeHexString(host_data_hexstring);   
    memcpy(attestation_report.host_data, hostData , strlen(host_data_hexstring)/2);

    *snp_report = (snp_attestation_report *) malloc (sizeof(snp_attestation_report));        
    memcpy(*snp_report, &attestation_report, sizeof(snp_attestation_report));

    return true;
}

// Main expects the hex string representation of the report data as the only argument
// Prints the raw binary format of the report so it can be consumed by the tools under
// the directory internal/guest/attestation
int main(int argc, char *argv[])
{    
    bool success;
    uint8_t *snp_report_hex;

    if (argc > 1) {        
        success = fetchAttestationReport(argv[1], argv[2], (void*) &snp_report_hex);    
    } else {        
        success = fetchAttestationReport("", "", (void*) &snp_report_hex);    
    }
   
    if (success == true) {
        for (size_t i = 0; i < sizeof(snp_attestation_report); i++) {
            fprintf(stdout, "%02x", (uint8_t) snp_report_hex[i]);            
        }

        return 0;
    }

    return -1;
}
