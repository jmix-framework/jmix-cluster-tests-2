package io.jmix.samples.cluster2.listener;

import io.jmix.sessions.events.JmixSessionCreatedEvent;
import io.jmix.sessions.events.JmixSessionDestroyedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.security.web.session.HttpSessionCreatedEvent;
import org.springframework.security.web.session.HttpSessionDestroyedEvent;
import org.springframework.session.Session;
import org.springframework.session.events.SessionCreatedEvent;
import org.springframework.session.events.SessionDestroyedEvent;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

@Component("cluster_TestAppSessionEventListener")
public class TestAppSessionEventListener {

    private final Logger log = LoggerFactory.getLogger(TestAppSessionEventListener.class);
    //todo synchronized with another option
    private List<JmixSessionCreatedEvent<?>> jmixCreatedEvents = Collections.synchronizedList(new ArrayList<>());
    private List<HttpSessionCreatedEvent> httpSessionCreatedEvents = Collections.synchronizedList(new ArrayList<>());
    private List<SessionCreatedEvent> sessionCreatedEvents = Collections.synchronizedList(new ArrayList<>());

    private List<JmixSessionDestroyedEvent> jmixDestroyedEvents = Collections.synchronizedList(new ArrayList<>());
    private List<HttpSessionDestroyedEvent> httpSessionDestroyedEvents = Collections.synchronizedList(new ArrayList<>());
    private List<SessionDestroyedEvent> sessionDestroyedEvents = Collections.synchronizedList(new ArrayList<>());


    @EventListener
    public void onHttpSessionCreated(final HttpSessionCreatedEvent event) {
        log.info("HttpSessionCreatedEvent: {} ({})", event.getSession().getId(), event.getSource());
        httpSessionCreatedEvents.add(event);
    }


    @EventListener
    public void onSessionCreated(final SessionCreatedEvent event) {
        log.info("SessionCreatedEvent: {} ({})", event.getSessionId(), event.getSource());
        sessionCreatedEvents.add(event);
    }

    @EventListener
    public void onJmixSessionCreated(final JmixSessionCreatedEvent<Session> event) {
        log.info("JmixSessionCreatedEvent: {} ({})", event.getSession().getId(), event.getSource());
        jmixCreatedEvents.add(event);
    }


    @EventListener
    public void onHttpSessionDestroyed(final HttpSessionDestroyedEvent event) {
        log.info("HttpSessionDestroyedEvent: {} ({})", event.getSession().getId(), event.getSource());
        httpSessionDestroyedEvents.add(event);
    }

    @EventListener
    public void onSessionDestroyed(final SessionDestroyedEvent event) {
        log.info("SessionDestroyedEvent: {} ({})", event.getSessionId(), event.getSource());
        sessionDestroyedEvents.add(event);
    }

    @EventListener
    public void onJmixSessionDestroyed(final JmixSessionDestroyedEvent event) {
        log.info("JmixSessionDestroyedEvent: {} ({})", event.getSession().getId(), event.getSource());
        jmixDestroyedEvents.add(event);
    }

    public List<JmixSessionCreatedEvent<?>> getJmixCreatedEvents() {
        return jmixCreatedEvents;
    }

    public List<HttpSessionCreatedEvent> getHttpSessionCreatedEvents() {
        return httpSessionCreatedEvents;
    }

    public List<SessionCreatedEvent> getSessionCreatedEvents() {
        return sessionCreatedEvents;
    }

    public List<JmixSessionDestroyedEvent> getJmixDestroyedEvents() {
        return jmixDestroyedEvents;
    }

    public List<HttpSessionDestroyedEvent> getHttpSessionDestroyedEvents() {
        return httpSessionDestroyedEvents;
    }

    public List<SessionDestroyedEvent> getSessionDestroyedEvents() {
        return sessionDestroyedEvents;
    }

    public void clearAllEvents() {
        jmixCreatedEvents.clear();
        httpSessionCreatedEvents.clear();
        sessionCreatedEvents.clear();
        jmixDestroyedEvents.clear();
        httpSessionDestroyedEvents.clear();
        sessionDestroyedEvents.clear();
    }
}