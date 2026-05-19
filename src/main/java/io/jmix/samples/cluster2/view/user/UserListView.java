package io.jmix.samples.cluster2.view.user;

import com.vaadin.flow.router.Route;
import io.jmix.flowui.view.*;
import io.jmix.samples.cluster2.entity.User;
import io.jmix.samples.cluster2.view.main.MainView;

@Route(value = "users", layout = MainView.class)
@ViewController(id = "User.list")
@ViewDescriptor(path = "user-list-view.xml")
@LookupComponent("usersDataGrid")
@DialogMode(width = "64em")
public class UserListView extends StandardListView<User> {
}
