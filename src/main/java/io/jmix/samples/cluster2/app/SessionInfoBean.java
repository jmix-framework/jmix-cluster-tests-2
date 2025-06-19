package io.jmix.samples.cluster2.app;

import io.jmix.audit.UserSessions;
import io.jmix.core.session.SessionData;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.session.SessionRegistry;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.session.Session;
import org.springframework.session.SessionRepository;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service("cluster_SessionInfoBean")
public class SessionInfoBean {
    @Autowired
    private SessionRegistry sessionRegistry;

    @Autowired
    private UserSessions userSessions;

    @Autowired
    private SessionRepository sessionRepository;

    @Autowired
    private ObjectProvider<SessionData> sessionDataProvider;

    public void setSessionDataAttribute(String name, String value) {
        sessionDataProvider.getObject().setAttribute(name, value);
    }

    public Object getSessionDataAttribute(String name) {
        return sessionDataProvider.getObject().getAttribute(name);
    }

    public String getSessionId() {
        return sessionDataProvider.getObject().getSessionId();
    }

    public String getSessions() {
        StringBuilder builder = new StringBuilder();
        List<String> sessionIds = new ArrayList<>();

        builder.append("===== SessionRegistry (UserSessions): =====\n");
        userSessions.sessions().forEach(us -> {
            Object principal = us.getPrincipal();
            builder.append("   -   ")
                    .append((principal instanceof UserDetails ud) ? ud.getUsername() : principal)
                    .append("\t : ")
                    .append(us.getSessionInformation().getSessionId())
                    .append(" | ")
                    .append(us.getSessionInformation().getLastRequest())
                    .append("\n");
            sessionIds.add(us.getSessionId());
        });


        builder.append("\n\n")
                .append("===== SessionRepository: =====\n");

        sessionIds.forEach(id -> {
            builder.append("   -   ")
                    .append("[").append(id).append("]:");

            Session session = sessionRepository.findById(id);

            if (session != null) {
                builder.append(session.isExpired() ? "EXPIRED" : "ACTIVE")
                        .append(" | ")
                        .append(session.getMaxInactiveInterval())
                        .append(" | ")
                        .append(session.getLastAccessedTime())
                        .append("\n");
            } else {
                builder.append("null\n");
            }

        });

        builder.append("\n\n")
                .append("===== SessionData: =====\n");

        SessionData sessionData = sessionDataProvider.getObject();

        for (String attributeName : sessionData.getAttributeNames()) {
            builder.append('\'')
                    .append(attributeName)
                    .append("':'")
                    .append(sessionData.getAttribute(attributeName))
                    .append("'\n");
        }

        return builder.toString();
    }
}