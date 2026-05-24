package io.jmix.samples.cluster2.test_support;

import io.jmix.flowui.UiEventPublisher;
import io.jmix.notificationsflowui.event.VaadinSessionNotificationEvent;
import io.jmix.notificationsflowui.event.VaadinSessionNotificationEventPublisher;
import org.springframework.context.annotation.Primary;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

@Primary
@Component("cluster_CollectingUserSessionNotifier")
public class CollectingUserSessionNotifier extends VaadinSessionNotificationEventPublisher {
    protected List<String> notifications = Collections.synchronizedList(new ArrayList<>());

    public CollectingUserSessionNotifier(UiEventPublisher uiEventPublisher) {
        super(uiEventPublisher);
    }

    @Override
    public void notifyUserSession(String username) {
        notifications.add(username);
        super.notifyUserSession(username);
    }

    @EventListener
    public void onUiUserEvent(UiEventPublisher.UiUserEvent event) {
        if (!(event.getEvent() instanceof VaadinSessionNotificationEvent notificationEvent)) {
            return;
        }

        String username = notificationEvent.getUsername();
        if (username != null) {
            notifications.add(username);
            return;
        }

        Collection<String> usernames = event.getUsernames();
        if (usernames != null) {
            notifications.addAll(usernames);
        }
    }

    public List<String> getNotifications() {
        synchronized (notifications) {
            return new ArrayList<>(notifications);
        }
    }

    public void clear() {
        notifications.clear();
    }
}
