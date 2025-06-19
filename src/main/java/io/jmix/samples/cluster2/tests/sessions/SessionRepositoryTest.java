package io.jmix.samples.cluster2.tests.sessions;


import io.jmix.samples.cluster2.listener.TestAppSessionEventListener;
import io.jmix.samples.cluster2.test_system.model.TestContext;
import io.jmix.samples.cluster2.test_system.model.annotations.ClusterTest;
import io.jmix.samples.cluster2.test_system.model.annotations.Step;
import io.restassured.path.json.JsonPath;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import org.apache.http.HttpStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.session.SessionRepository;
import org.springframework.stereotype.Component;

import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.fail;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItems;


@Component("cluster_SessionRepositoryTest")
@ClusterTest(description = "Checks HazelcastIndexedSessionRepository works correctly in cluster", cleanStart = true)
public class SessionRepositoryTest {

    private static final Logger log = LoggerFactory.getLogger(SessionRepositoryTest.class);
    public static final String TOKEN_ATTR = "AUTH_TOKEN";

    public static final String CLIENT_ID = "my-client";
    public static final String CLIENT_SECRET = "my-secret";

    public static final String KEY_1 = "key1";
    public static final String VALUE_1_INITIAL = "value1_initial";
    public static final String VALUE_1_UPDATED_BY_NODE_2 = "value1_updated";
    public static final String KEY_2 = "key2";
    public static final String VALUE_2_INITIAL = "value2";
    public static final String SESSION_ID = "sessionId";


    @Autowired
    private SessionRepository sessionRepository;

    @Autowired
    private TestAppSessionEventListener sessionEventListener;


    @Step(order = 1, nodes = "1")
    public void checkSessionAttributesPropagation(TestContext context) {

        Map<String, TestContext.NodeInfo> nodeInfos = context.getNodeMap();
        String node1Ip = nodeInfos.get("1").getIp();
        String node2Ip = nodeInfos.get("2").getIp();

        String token = obtainToken(node1Ip);
        log.info("token obtained successfully for '{}:8080': {}", node1Ip, token);

        String sessionId = baseRequest(token, node1Ip).get("rest/services/cluster_SessionInfoBean/getSessionId").getBody().asString();
        log.info("sessionId: " + sessionId);
        context.put(SESSION_ID, sessionId);

        context.put(TOKEN_ATTR, token);

        baseRequest(token, node1Ip)
                .get("rest/entities/cluster_User")
                .then().statusCode(HttpStatus.SC_OK)
                .body("username", hasItems("admin", "test"));

        baseRequest(token, node1Ip)
                .queryParam("name", KEY_1)
                .queryParam("value", VALUE_1_INITIAL)
                .get("rest/services/cluster_SessionInfoBean/setSessionDataAttribute")
                .then().statusCode(HttpStatus.SC_NO_CONTENT);


        baseRequest(token, node2Ip)
                .queryParam("name", KEY_2)
                .queryParam("value", VALUE_2_INITIAL)
                .get("rest/services/cluster_SessionInfoBean/setSessionDataAttribute")
                .then().statusCode(HttpStatus.SC_NO_CONTENT);


        log.info("updating attribute on first node");
        baseRequest(token, node2Ip)
                .queryParam("name", KEY_1)
                .queryParam("value", VALUE_1_UPDATED_BY_NODE_2)
                .get("rest/services/cluster_SessionInfoBean/setSessionDataAttribute");

        Response sessionsResponse = baseRequest(token, node1Ip)
                .get("rest/services/cluster_SessionInfoBean/getSessions");

        sessionsResponse.then().statusCode(HttpStatus.SC_OK);

        log.info("Sessions for 1 node: \n {}\n============", sessionsResponse.asString());


        Response secondNodeSessionsResponse = baseRequest(token, node2Ip)
                .get("rest/services/cluster_SessionInfoBean/getSessions");

        secondNodeSessionsResponse.then().statusCode(HttpStatus.SC_OK);

        log.info("Sessions for 2 node: \n {}\n============", secondNodeSessionsResponse.asString());


        baseRequest(token, node1Ip)
                .queryParam("name", KEY_2)
                .get("rest/services/cluster_SessionInfoBean/getSessionDataAttribute")
                .then().statusCode(HttpStatus.SC_OK)
                .body(containsString(VALUE_2_INITIAL));

        baseRequest(token, node1Ip)
                .queryParam("name", KEY_1)
                .get("rest/services/cluster_SessionInfoBean/getSessionDataAttribute")
                .then().statusCode(HttpStatus.SC_OK)
                .body(containsString(VALUE_1_UPDATED_BY_NODE_2));
    }


    @Step(order = 2, nodes = "2")
    public void destroySessionOnSecondNode(TestContext context) {
        sessionRepository.deleteById((String) context.get(SESSION_ID));
        log.info("Session destroyed: {}", context.get(SESSION_ID));
    }


    @Step(order = 3, nodes = "3")
    public void checkEventsOnThirdNode(TestContext context) {
        assertThat(sessionEventListener.getHttpSessionCreatedEvents()).hasSize(1);
        assertThat(sessionEventListener.getHttpSessionCreatedEvents().get(0).getSession().getId()).isEqualTo(context.get(SESSION_ID));

        assertThat(sessionEventListener.getSessionCreatedEvents()).hasSize(1);
        assertThat(sessionEventListener.getSessionCreatedEvents().get(0).getSession().getId()).isEqualTo(context.get(SESSION_ID));

        assertThat(sessionEventListener.getHttpSessionDestroyedEvents()).hasSize(1);
        assertThat(sessionEventListener.getHttpSessionDestroyedEvents().get(0).getSession().getId()).isEqualTo(context.get(SESSION_ID));

        assertThat(sessionEventListener.getSessionDestroyedEvents()).hasSize(1);
        assertThat(sessionEventListener.getSessionDestroyedEvents().get(0).getSession().getId()).isEqualTo(context.get(SESSION_ID));
    }


    protected static String obtainToken(String host) {
        Response response = given()
                .baseUri("http://" + host + ":8080")
                .auth().preemptive().basic(CLIENT_ID, CLIENT_SECRET)
                .contentType("application/x-www-form-urlencoded")
                .formParam("grant_type", "client_credentials")
                .post("/oauth2/token");

        if (response.getStatusCode() != HttpStatus.SC_OK) {
            fail("Auth token request failed: %s: %s",
                    response.getStatusLine(),
                    response.getBody().asString());
        }

        return JsonPath.from(response.getBody().asString()).get("access_token");
    }

    protected static RequestSpecification baseRequest(String token, String host) {
        return given().baseUri("http://" + host + ":8080").auth().oauth2(token);
    }
}
