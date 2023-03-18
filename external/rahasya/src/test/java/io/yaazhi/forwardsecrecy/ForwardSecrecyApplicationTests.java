package io.yaazhi.forwardsecrecy;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.security.Security;

import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import io.yaazhi.forwardsecrecy.controller.ECCController;

/*
Test cases
*/
@SpringBootTest
class ForwardSecrecyApplicationTests {

	@Autowired
	ECCController eccController;

	@BeforeAll
	public static void beforeAll(){
		Security.addProvider(new BouncyCastleProvider()); 
	}
	@Test
	void contextLoads() {
		assertTrue(true);
	}

}