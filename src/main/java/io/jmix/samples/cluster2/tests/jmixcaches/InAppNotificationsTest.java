package io.jmix.samples.cluster2.tests.jmixcaches;

import io.jmix.notifications.NotificationManager;
import io.jmix.notifications.channel.impl.InAppNotificationChannel;
import io.jmix.samples.cluster2.test_support.CollectingUserSessionNotifier;
import io.jmix.samples.cluster2.test_system.model.TestContext;
import io.jmix.samples.cluster2.test_system.model.annotations.AfterTest;
import io.jmix.samples.cluster2.test_system.model.annotations.ClusterTest;
import io.jmix.samples.cluster2.test_system.model.annotations.Step;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Component("cluster_InAppNotificationsTest")
@ClusterTest(description = "To make sure that notification created on one node will be displayed on ui for another node")
public class InAppNotificationsTest {

    private static final Logger log = LoggerFactory.getLogger(InAppNotificationsTest.class);
    private static final String TEST_USERNAME_PREFIX = "notification_test_";
    private static final String TEST_USERNAME = "testUsername";
    private static final String TEST_SUBJECT = "testSubject";
    private static final String TEST_BODY = "testBody";
    private static final long NOTIFICATION_WAIT_TIMEOUT_MS = 10_000;
    private static final long NOTIFICATION_WAIT_INTERVAL_MS = 200;

    @Autowired
    private InAppNotificationChannel inAppNotificationChannel;
    @Autowired
    private CollectingUserSessionNotifier userSessionNotifier;
    @Autowired
    private NotificationManager notificationManager;
    @Autowired
    private DataSource dataSource;

    @Step(order = 0)
    public void prepareNotifier() {
        userSessionNotifier.clear();
    }

    @Step(order = 1, nodes = "1")
    public void stepOne(TestContext context) {
        userSessionNotifier.clear();

        String username = TEST_USERNAME_PREFIX + UUID.randomUUID();
        String subject = "T1 " + username;
        String body = "test notification " + username;
        context.put(TEST_USERNAME, username);
        context.put(TEST_SUBJECT, subject);
        context.put(TEST_BODY, body);

        createTestUser(username);

        log.info("Sending notification on node 1");
        notificationManager.createNotification()
                .withSubject(subject)
                .withRecipientUsernames(username)
                .toChannels(inAppNotificationChannel)
                .withBody(body)
                .send();

        waitAndAssertNotificationDelivery(username, 2);
        assertStoredNotification(username, subject, body);
    }

    @Step(order = 2, nodes = "2")
    public void stepTwo(TestContext context) {
        log.info("Node 2 must be notified");
        String username = (String) context.get(TEST_USERNAME);
        String subject = (String) context.get(TEST_SUBJECT);
        String body = (String) context.get(TEST_BODY);

        waitAndAssertNotificationDelivery(username, 1);
        assertStoredNotification(username, subject, body);
    }

    @AfterTest
    public void after(TestContext context) {
        String username = (String) context.get(TEST_USERNAME);
        if (username != null) {
            removeTestNotifications(username);
            removeTestUser(username);
        }
    }

    protected void waitAndAssertNotificationDelivery(String username, int expectedDeliveryCount) {
        waitForExpectedNotificationDelivery(username, expectedDeliveryCount);
        assertNotificationDelivery(username, expectedDeliveryCount);
    }

    protected void waitForExpectedNotificationDelivery(String username, int expectedDeliveryCount) {
        long deadline = System.currentTimeMillis() + NOTIFICATION_WAIT_TIMEOUT_MS;
        while (System.currentTimeMillis() < deadline
                && !isExpectedNotificationDeliveryReached(username, expectedDeliveryCount)) {
            try {
                Thread.sleep(NOTIFICATION_WAIT_INTERVAL_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException("Interrupted while waiting for in-app notification propagation", e);
            }
        }
    }

    protected void assertNotificationDelivery(String username, int expectedDeliveryCount) {
        assertThat(userSessionNotifier.getNotifications())
                .containsExactlyInAnyOrderElementsOf(Collections.nCopies(expectedDeliveryCount, username));
    }

    protected void assertStoredNotification(String username, String subject, String body) {
        assertThat(countTestNotifications(username, subject, body)).isEqualTo(1);
    }

    protected boolean isExpectedNotificationDeliveryReached(String username, int expectedDeliveryCount) {
        List<String> notifications = userSessionNotifier.getNotifications();
        return Collections.frequency(notifications, username) == expectedDeliveryCount
                && notifications.size() == expectedDeliveryCount;
    }

    protected void createTestUser(String username) {
        jdbcTemplate().update(
                "insert into CLUSTER_USER (ID, VERSION, USERNAME, PASSWORD, ACTIVE) values (?, ?, ?, ?, ?)",
                UUID.randomUUID(),
                1,
                username,
                "{noop}" + username,
                true);
    }

    protected void removeTestNotifications(String username) {
        jdbcTemplate().update("delete from NTF_IN_APP_NOTIFICATION where RECIPIENT = ?", username);
    }

    protected void removeTestUser(String username) {
        jdbcTemplate().update("delete from CLUSTER_USER where USERNAME = ?", username);
    }

    protected int countTestNotifications(String username, String subject, String body) {
        return jdbcTemplate().queryForObject(
                "select count(*) from NTF_IN_APP_NOTIFICATION " +
                        "where RECIPIENT = ? and SUBJECT = ? and BODY = ?",
                Integer.class,
                username,
                subject,
                body);
    }

    protected JdbcTemplate jdbcTemplate() {
        return new JdbcTemplate(dataSource);
    }

}
