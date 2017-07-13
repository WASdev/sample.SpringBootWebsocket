# Running a Spring Boot WebSocket Application on Liberty Using Maven [![Build Status](https://travis-ci.org/WASdev/sample.SpringBootWebsocket.svg?branch=master)](https://travis-ci.org/WASdev/sample.SpringBootWebsocket)

This tutorial demonstrates the entire process of modifying a sample Spring Boot WebSocket project to run as a packaged Liberty assembly. The end result is a standalone runnable JAR which contains the WebSocket application deployed on a Liberty server.

We're going to be building off Spring Boot's "gs-messaging-stomp-websocket" [sample project](https://github.com/spring-guides/gs-messaging-stomp-websocket/). Spring Boot also provides a [guide on their website](https://spring.io/guides/gs/messaging-stomp-websocket/) which explains their project code in great detail.

### Table of Contents

* [Getting Started](#start)
* [Modifying the POM](#pom)
* [Server Configuration](#server)
* [Code Changes](#code)
* [Final Issues](#issues)
* [Conclusion](#conclusion)

## <a name="start"></a>Getting Started

Start by downloading/cloning the code from Spring's "gs-messaging-stomp-websocket" [sample project](https://github.com/spring-guides/gs-messaging-stomp-websocket/). All the modifications in this guide will be made on the code in the ["complete" folder](https://github.com/spring-guides/gs-messaging-stomp-websocket/tree/master/complete) of that project. Thus, we suggest familiarizing yourself with that code and reading the guide before proceeding.

## <a name="pom"></a>Modifying the POM

We'll start by modifying the `pom.xml` in order to configure the project to run on a Liberty server. 

### Change the Packaging Type

First, set the packaging type to `liberty-assembly`. This can be added after the `version` parameter near the top of the file:

```
<packaging>liberty-assembly</packaging>
```

From our [Liberty Maven Plugin](https://github.com/WASdev/ci.maven/tree/tools-integration) documentation:

> The liberty-assembly Maven packaging type is used to create a packaged Liberty server Maven artifact out of existing server installation, compressed archive, or another server Maven artifact. Any applications specified as Maven compile dependencies will be automatically packaged with the assembled server. Liberty features can also be installed and packaged with the assembled server. Any application or test code included in the project is automatically compiled and tests run at appropriate unit or integration test phase. Application code is installed as a loose application WAR file if installAppPackages is set to all or project and looseApplication is set to true.

### Update Project Name

Optionally, we also change the name of the Maven project to `websocketApp`:

```
<name>websocketApp</name>
```

### Add Liberty Dependencies

For this sample project, we'll be using Liberty (version 16.0.0.4) with Java EE 7 Web Profile. Add the following dependencies to get this Liberty runtime:

```
<dependency>
	<groupId>com.ibm.websphere.appserver.runtime</groupId>
	<artifactId>wlp-webProfile7</artifactId>
	<version>16.0.0.4</version>
	<type>zip</type>
</dependency>

<dependency>
	<groupId>net.wasdev.maven.tools.targets</groupId>
	<artifactId>liberty-target</artifactId>
	<version>16.0.0.4</version>
	<type>pom</type>
	<scope>provided</scope>
	<exclusions>
		<exclusion>
			<groupId>javax.security.auth.message</groupId>
			<artifactId>javax.security.auth.message-api</artifactId>
		</exclusion>
	</exclusions>
</dependency>
```

### Modify Spring Boot Dependencies

We'll also need to make a modification to the `org.springframework.boot.spring-boot-starter-websocket` dependency. Specifically, we exclude `spring-boot-starter-tomcat` from this dependency as we are running the application on Liberty:

```
<exclusions>
	<exclusion>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-tomcat</artifactId>
	</exclusion>
</exclusions>
```

Note: According to our logs, the Liberty implementation of websocket will not be used if you don't add the exclusion above. 

### Add Arquillian Dependencies

We'll be using [Arquillian](http://arquillian.org/) to run our integration tests, instead of the default Spring Boot testing framework. This is because we want run our test cases on our Liberty server, rather than using a Spring Boot embedded server. To do this, we'll be using the `arquillian-wlp-managed` container and providing the appropriate configuration in the next section.

To add Arquillian to our project, first add `arquillian-bom` under the `dependencyManagement` section of the POM:

```
<dependencyManagement>
	...
	<dependencies>
		<dependency>
			<groupId>org.jboss.arquillian</groupId>
			<artifactId>arquillian-bom</artifactId>
			<version>1.1.13.Final</version>
			<scope>import</scope>
			<type>pom</type>
		</dependency>
	</dependencies>
    ...
</dependencyManagement>
```

Next, add the following dependencies:

```
<dependency>
	<groupId>junit</groupId>
	<artifactId>junit</artifactId>
	<scope>test</scope>
</dependency>

<dependency>
	<groupId>org.jboss.arquillian.container</groupId>
	<artifactId>arquillian-wlp-managed-8.5</artifactId>
	<version>1.0.0.Beta2</version>
	<scope>test</scope>
</dependency>

<dependency>
	<groupId>org.jboss.shrinkwrap.resolver</groupId>
	<artifactId>shrinkwrap-resolver-impl-maven</artifactId>
	<scope>test</scope>
</dependency>

<dependency>
	<groupId>org.jboss.arquillian.junit</groupId>
	<artifactId>arquillian-junit-container</artifactId>
	<scope>test</scope>
</dependency>
```

### Add POM Properties

Add the following properties to the POM properties list:

```
<properties>
   ...
    <start-class>hello.Application</start-class>
    <!-- Liberty server properties -->
    <wlpServerName>WebsocketServer</wlpServerName>
    <testServerHttpPort>9080</testServerHttpPort>
    <testServerHttpsPort>9443</testServerHttpsPort>
    ...
</properties>
```

Note the addition of the `<start-class>` property. We'll discuss this is greater detail in the [Code Changes](#code) section.

### Add the `liberty-maven-plugin`

We now add version `2.0` of the `liberty-maven-plugin` and configure it:

```
<plugin>
	<groupId>net.wasdev.wlp.maven.plugins</groupId>
	<artifactId>liberty-maven-plugin</artifactId>
	<version>2.0</version>
	<extensions>true</extensions>
	<!-- Specify configuration, executions for liberty-maven-plugin -->
	<configuration>
		<serverName>websocketServer</serverName>
		<assemblyArtifact>
			<groupId>com.ibm.websphere.appserver.runtime</groupId>
			<artifactId>wlp-webProfile7</artifactId>
			<version>16.0.0.4</version>
			<type>zip</type>
		</assemblyArtifact>
		<assemblyInstallDirectory>${project.build.directory}</assemblyInstallDirectory>
		<!-- <configFile>src/main/liberty/config/server.xml</configFile> -->
		<packageFile>${project.build.directory}/WebsocketServerPackage.jar</packageFile>
		<bootstrapProperties>
			<default.http.port>9080</default.http.port>
			<default.https.port>9443</default.https.port>
		</bootstrapProperties>
		<features>
			<acceptLicense>true</acceptLicense>
		</features>
		<include>runnable</include>
		<installAppPackages>all</installAppPackages>
		<appsDirectory>apps</appsDirectory>
		<stripVersion>true</stripVersion>
		<looseApplication>true</looseApplication>
		<skipTestServer>true</skipTestServer>
	</configuration>
</plugin>
```

Here, we create a server called "websocketServer" and set the `packageFile` parameter to the desired file name and location of our packaged server. As per our `package-server` goal [guidelines](https://github.com/WASdev/ci.maven/blob/master/docs/package-server.md), we add `<include>runnable</include>` to the configuration to indicate that we want to package the server into a runnable JAR. Notice also that in our `install-apps` execution goal, we set `<appsDirectory>apps</appsDirectory>` to indicate that we want our application to be installed in the `apps` directory of the server rather than the default `dropins` directory. Note that this is an optional modification. 

Furthermore, note that we added the `skipTestServer` parameter with value `true`. This skips the `test-start-server` and `test-stop-server` goals which, by default, run in the `pre-integration-test` and `post-integration-test` build phases respectively. We need to remove these goals as the Arquillian container for Liberty expects that the server be created, but not running, when the integration tests run. 

As an aside, we can also remove the `spring-boot-maven-plugin` which was included by default in the POM. The `liberty-maven-plugin` is the only plugin you will need for this project.

## <a name="server"></a>Server Configuration

After modifying our POM, the next step is to create a `server.xml` file and add our server configuration. By default, this file should be located at `src/test/resources/server.xml`, although you can modify this by changing the `configFile` configuration parameter in the `liberty-maven-plugin` (we provide this code in our example above, although it is commented out because we're using the default location for this sample project). 

Once you have created your `server.xml` file, add the following code:

```
<?xml version="1.0" encoding="UTF-8"?>
<server description="new server">
	<application context-root="/"
		location="gs-messaging-stomp-websocket.war"></application>

	<!-- Enable features -->
	<featureManager>
		<feature>jsp-2.3</feature>
		<feature>websocket-1.1</feature>
		<feature>localConnector-1.0</feature>
	</featureManager>

	<!-- To access this server from a remote client add a host attribute to 
		the following element, e.g. host="*" -->
	<httpEndpoint id="defaultHttpEndpoint" httpPort="9080"
		httpsPort="9443" />

	<!-- Automatically expand WAR files and EAR files -->
	<applicationManager autoExpand="true" />

	<!-- Automatically load the Spring application endpoint once the server 
		is ready. -->
	<webContainer deferServletLoad="false" />

</server>
```

There are a few notable things happening in this configuration:

* We set the context root of our application to the server root. This is done in order to maintain consistency with the file paths specified in the sample project, as Spring Boot applications running on embedded servers are located at the server root. 
* In our `featureManager`, we add the `jsp-2.3` and `localConnector-1.0` features which are required for Arquillian. Note that `jsp-2.3` includes `servlet-3.1`. We also add the `websocket-1.1` feature because we want to use Liberty's WebSocket implementation in our project. 
* We set `<applicationManager autoExpand="true" />` to automatically expand our WAR file. If you have the WDT (WebSphere Development Tools) plugin installed in Eclipse, you might see an error on this line. You can ignore this, as it will be resolved when `server.xml` is copied to the server.
* We set `<webContainer deferServletLoad="false" />` to automatically load the Spring Boot application once the server is ready. 

We also have to add the appropriate Arquillian configuration for our integration test to run properly. Create a file named `arquillian.xml` in `src/test/resources` and add the following:

```
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<arquillian xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns="http://jboss.org/schema/arquillian"
	xsi:schemaLocation="http://jboss.org/schema/arquillian http://jboss.org/schema/arquillian/arquillian_1_0.xsd">
	<engine>
		<property name="deploymentExportPath">target/</property>
	</engine>
	<container qualifier="websphere" default="true">
		<configuration>
			<property name="wlpHome">target/wlp</property>
			<property name="serverName">websocketServer</property>
			<property name="httpPort">9080</property>
			<property name="outputToConsole">true</property>
			<property name="appDeployTimeout">600</property>
		</configuration>
	</container>
</arquillian>
```

You may have to change the value of the `wlpHome` property to the appropriate directory where your server was installed. You can read [this article](https://developer.ibm.com/wasdev/docs/getting-started-liberty-arquillian/) for more information and another example of using Arquillian with Liberty. 

## <a name="code"></a>Code Changes

We're now ready to make changes to our source code. This section is broken up by the type of changes we need to make.

### Startup Changes

We previously briefly mentioned the importance of setting the `<start-class>` parameter in the POM properties. The importance of this is evident now, as we're about to change how our WebSocket application is launched. 

Traditionally, a Spring Boot application running on an embedded server such as Tomcat simply calls `SpringApplication.run(...)` in its main class (in this case `hello.Application`). However, we must change this when deploying our application as a servlet to our Liberty server. Specifically, we're going to have our start class extend `SpringBootServletInitializer` in order to run our application as a WAR. Then, by setting this class as our `<start-class>` parameter, we specify that our application starts its execution from this class. 

To make these changes, replace the original code in `Application.java` with the following:

**`src/main/java/hello/Application.java`**

```
package hello;

import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.support.SpringBootServletInitializer;

@SpringBootApplication
public class Application extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(Application.class);
    }
    
}
```

### Integration Test Changes

The `liberty-maven-plugin` integrates the `maven-failsafe-plugin` to run integration tests after the server has been created. According to the `maven-failsafe-plugin` [documentation](http://maven.apache.org/surefire/maven-failsafe-plugin/examples/inclusion-exclusion.html), the plugin will automatically include all test cases that match the `**/*IT.java` wildcard pattern. Thus, we rename the test class name from `GreetingIntegrationTests` to `GreetingIntegrationTestIT`. 

Alternatively, you can configure the plugin to include specific tests by name which do not match this pattern. 

Next, change the `@RunWith(SpringRunner.class)` annotation to `@RunWith(Arquillian.class)` to indicate that we want to use Arquillian to run the test case. 

We'll also be using the static server port defined in our POM (9080) instead of using a randomly generated port, as Spring Boot does. As such, remove the `@SpringBootTest` annotation, the `@LocalServerPort` annotation and `port` variable declaration at the beginning of the class. Also, since we're not using the `port` variable anymore, change this line (line 94 in the original code):

```
this.stompClient.connect("ws://localhost:{port}/gs-guide-websocket", this.headers, handler, this.port);
``` 

to this:

```
this.stompClient.connect("ws://localhost:9080/gs-guide-websocket", this.headers, handler);
```

As specified in Arquillian's [Getting Started Guide](http://arquillian.org/guides/getting_started/#write_an_arquillian_test), we'll also need to add a public static method with the `@Deployment` annotation, which returns a ShrinkWrap archive. This archive contains the test case, as well as any dependencies the test case needs to run. It is deployed and runs on the server alongside the application during the testing process. 

We create this archive in the following manner:

```
@Deployment
public static WebArchive createDeployment() {

	// Import Maven runtime dependencies
	File[] mavenFiles = Maven.resolver().loadPomFromFile("pom.xml").importRuntimeDependencies().resolve()
			.withTransitivity().asFile();

	// Create deploy file
	WebArchive war = ShrinkWrap.create(WebArchive.class).addPackage("hello").addAsLibraries(mavenFiles);

	// Show the deploy structure
	System.out.println(war.toString(true));

	return war;
}
```

The archive includes all the runtime dependencies from our POM, as well as all our of source classes, which are referenced from the test case code.

Note that in our sample code, we increase the integration test timeout from 3 seconds to 5 seconds. This is to ensure the test has sufficient time to run in Travis. 

## <a name="issues"></a>Final Issues

There are just a few small changes we have to make before our WebSocket application can run on Liberty. We describe them here:

### WebJars Locator

Because Liberty uses the `wsjar` prefix by default instead of the standard `jar` prefix, `webjar-locator` is not compatible with Liberty without some additional configuration. To resolve this issue, add the following line to `server.xml`:

```
<classloading useJarUrls="true" />
```

According to our [documentation](https://www.ibm.com/support/knowledgecenter/SSEQTP_liberty/com.ibm.websphere.liberty.autogen.base.doc/ae/rwlp_config_classloading.html), this flag determines whether to use `jar:` or `wsjar:` URLs for referencing files in archives. This will allow `webjars-locator` to find the JARs it needs. 

### SockJS

You might also experience an issue with SockJS version compatibility. If you're getting a message such as `Incompatibile SockJS! Main site uses: "1.0.2", the iframe: "1.0.0"` in the web console when trying to connect to your web socket, you'll need to replace 

`registry.addEndpoint("/gs-guide-websocket").withSockJS();`

with

`registry.addEndpoint("/gs-guide-websocket").withSockJS().setClientLibraryUrl("/webjars/sockjs-client/1.0.2/sockjs.min.js");`

in your `WebSocketConfig` class. If you update the version of your `sockjs-client` dependency in the future, just remember to update the version number here and in `index.html`. 

Although, these changes won't be necessary if a WebSphere-compatible version of `webjars-locator` is released in the future.

## <a name="conclusion"></a>Conclusion

Congratulations! You should now be able to run your WebSocket application on Liberty by executing `mvn install liberty:run-server`. By navigating to `http://localhost:9080/`, you should see the application appear and behave in the same way as it does standalone. Additionally, you'll see that a JAR named `WebsocketServerPackage.jar` was created in the `target` directory, which bundles your application with the Liberty server you configured into a standalone runnable JAR. 

Please feel free to download our sample code from this repository, or create a Github Issue if you have any additional questions.
