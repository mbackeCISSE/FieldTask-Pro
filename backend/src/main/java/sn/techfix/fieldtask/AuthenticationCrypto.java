package sn.techfix.fieldtask;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

final class AuthenticationCrypto {
  private static final int PASSWORD_ITERATIONS = 210_000;
  private static final int PASSWORD_BITS = 256;

  private AuthenticationCrypto() {}

  static boolean verifyPassword(String password, String saltBase64, String expectedBase64) {
    if (password == null || saltBase64 == null || expectedBase64 == null) return false;
    char[] chars = password.toCharArray();
    PBEKeySpec spec = null;
    try {
      spec = new PBEKeySpec(chars, Base64.getDecoder().decode(saltBase64),
          PASSWORD_ITERATIONS, PASSWORD_BITS);
      byte[] actual = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
          .generateSecret(spec).getEncoded();
      byte[] expected = Base64.getDecoder().decode(expectedBase64);
      return MessageDigest.isEqual(actual, expected);
    } catch (IllegalArgumentException | GeneralSecurityException exception) {
      return false;
    } finally {
      if (spec != null) spec.clearPassword();
      java.util.Arrays.fill(chars, '\0');
    }
  }

  static String tokenHash(String token) {
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256")
          .digest(token.getBytes(StandardCharsets.UTF_8));
      return java.util.HexFormat.of().formatHex(digest);
    } catch (GeneralSecurityException exception) {
      throw new IllegalStateException("SHA-256 indisponible.", exception);
    }
  }
}
