package io.jmix.samples.cluster2;

import com.google.common.base.Strings;
import com.vaadin.flow.component.page.AppShellConfigurator;
import com.vaadin.flow.component.page.Push;
import com.vaadin.flow.server.PWA;
import com.vaadin.flow.theme.Theme;
//import io.jmix.samples.cluster2.test_support.CollectingUserSessionNotifier;//todo notificatoins
import jakarta.annotation.PostConstruct;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.jmx.support.ConnectorServerFactoryBean;

import javax.management.MalformedObjectNameException;
import javax.sql.DataSource;

@Push
@Theme(value = "sample-cluster-2")
@PWA(name = "Sample Cluster 2", shortName = "Sample Cluster 2")
@SpringBootApplication
public class SampleCluster2Application implements AppShellConfigurator {

    @Autowired
    private Environment environment;

    public static void main(String[] args) {
        SpringApplication.run(SampleCluster2Application.class, args);
    }

    @Bean
    @Primary
    @ConfigurationProperties("main.datasource")
    DataSourceProperties dataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    @ConfigurationProperties("main.datasource.hikari")
    DataSource dataSource(final DataSourceProperties dataSourceProperties) {
        return dataSourceProperties.initializeDataSourceBuilder().build();
    }

    @Bean("serverConnector")
    ConnectorServerFactoryBean serverConnector() throws MalformedObjectNameException {
        ConnectorServerFactoryBean bean = new ConnectorServerFactoryBean();
        bean.setObjectName("connector:name=jmxmp");
        bean.setServiceUrl("service:jmx:jmxmp://localhost:9875");
        return bean;
    }

    /*@Bean //todo notificatons
    @Primary
    UserSessionNotifier testingUserSessionNotifier() {
        return new CollectingUserSessionNotifier();
    }
*/

    @EventListener
    public void printApplicationUrl(final ApplicationStartedEvent event) {
        LoggerFactory.getLogger(SampleCluster2Application.class).info("Application started at "
                + "http://localhost:"
                + environment.getProperty("local.server.port")
                + Strings.nullToEmpty(environment.getProperty("server.servlet.context-path")));
    }

/*    @PostConstruct //todo notificatoins
    public void postConstruct() {
        notificationTypesRepository.registerTypes(
                new NotificationType("info", "INFO_CIRCLE"),
                new NotificationType("warn", "WARNING")
        );
    }*/
}
