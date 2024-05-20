const { onRequest } = require("firebase-functions/v2/https");
const { google } = require('googleapis');
const logger = require("firebase-functions/logger");

// Function to get access token
exports.getAccessToken = onRequest(async (request, response) => {
  try {
    const privateKey = `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCQP2JIuoOx631z
ovyaspqUiZ9rPU6U9sfb11zgxqjbo0FLKbvyRR/5IOCvLqRsGxrb6kwqkIL0eWCq
mI4WS+CoV1BM2GmL+K3bi3b00vLdoTgSM23SWfwDd56Bri3Ee+uXg6g9rSr8+BBx
Zq4s+3vxb1WoXZG+wY54qc8TOfx25Nn/rkz/Dcwdlt/uRAGe7cL/bx+kpVFrn8Fz
evj5oRqqR4oS6aOrgRw6/PG5yBIS9+PFPWvrd6vyucLwjeFky9XsY4XGMBZnK4hq
GJt1KD2y2rUWpaUHKFatUA635UKaLNO6I7tijWEglZVtmINIeBPwRfeT0hCVXtq6
6UiAkoQTAgMBAAECggEAFZau7oSfrjK4+WQU21BMy1tXlTS9PJU8rz3pxChnYEvs
O0QZQXawBNizV/SqnhVmbTCBSsOLHezGl3Gynkqn6nn65i1jipPi7V9Po++ocpws
6Khy0M8v5RLzkaQQbH5BcdE+DlELBIZZ66b6/Xd8AtPvZX3vkLWmTY/Ykp+UlfSL
zeHtZIurq3s8vJGjZyBmZXl1JDl7OEZeCo9NoF1TTHsLqsuagJTMHQp4hKW5mE7z
sZYWYD5/GejIkvjKCjry2z9hRVmjSyaSOEFMrVKhuF66k4LqHiOxb5TJjuWJjYUT
6XHJaPrexKWuRagPsLOwReIvjdpxTOenpRI9ae0zRQKBgQDHn/3zuy5ZcjOtFsl/
n4xNxQvLVcMOYzZbZvoEfilvy2zPItYykYl7/OBUjjGFgLfiRIiX/zp1wkju9DSv
Wg0313+U4epCZf1XQDid5rcIrlVZw4LO29biahuiwvx7HznnZEVKUmhCN0XEibsO
dW4EGI3WyHhmg2a+RGxhTegw3QKBgQC4+9ndxkq9FtEWDwWvj5mwellykO0bluAQ
88qQjgaSnaXp1Ivv1lkQg+MuBWknu9oWB33Szg7Zci0WIQkHk7rRViWU3uy4OhTg
7JrrSIny129RHQth7qrKtgMTjUOzAOPGJpwqO/jqC7ZxSm26ICQs5yUzamBhivS+
NeTVPKVBrwKBgQCAsjHbz0IbYlfUcEtpnueqP63R4jGFdgrWNHZdLSTzsPcuNyxW
n6M+LxJFEQL2KbzjAAH71AzRXHb+rqvEnM7GwIS87ETFl9ETThDyI4q+6v2ViEkt
qWdIwtWcQg7aJZCEEA3n02bpwY6WHaFdufE6bMYMwWN126MCaURiGwLldQKBgBuc
S9qUXFd47mBygZDAyFnVCUDWbO2vSWZ+XP/SkxyTN059kR2NSuHyLZiS6i0qFtUu
7RLn+sNuDVi+OZDN9haE2zsrQv4EfVVNO5pey2hZy525zhch/pAfNrpWXYJ8YYMU
BD8xkGeus96ZE2OypHOnVKAmApjMmtdBSBSj5q61AoGBAIziz0eSXSKI9218vNvO
4xW4zwjyoQb+pP4phEX590qqzuohq6FCipg1yA3xDufcSeZ2bs4iffa0AzznTYM9
KfugLcqX1BIU2zaT0Ui94byPK6GD+bB//85Gx/EcA1wbAupiPkUwBt8dKM7H8s+t
ZMr+TkAw9wgfwekwIsQSWUVM
-----END PRIVATE KEY-----`;

    const credentials = {
      type: "service_account",
      project_id: "pingbear-96b4c",
      private_key_id: "0b9c3d15b138c8b33e982b97663d7d05764e6b3e",
      private_key: privateKey,
      client_email: "firebase-adminsdk-u51gq@pingbear-96b4c.iam.gserviceaccount.com",
      client_id: "112699471664954227175",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-u51gq%40pingbear-96b4c.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    };

    const scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    const jwtClient = new google.auth.JWT(
      credentials.client_email,
      null,
      credentials.private_key,
      scopes
    );

    jwtClient.authorize((err, tokens) => {
      if (err) {
        logger.error("Error obtaining access token:", err);
        response.status(500).send("Error obtaining access token");
        return;
      }

      logger.info("Access token obtained", { token: tokens.access_token });
      response.send({ accessToken: tokens.access_token });
    });
  } catch (err) {
    logger.error("Error obtaining access token:", err);
    response.status(500).send("Error obtaining access token");
  }
});