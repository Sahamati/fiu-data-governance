package io.yaazhi.forwardsecrecy.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.NonNull;
import lombok.ToString;

@ToString(includeFieldNames=true)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class SecretKeySpec{

    @NonNull
    String remotePublicKey;
    @NonNull
    String ourPrivateKey;
    
   // public SecretKeySpec() {}
}

