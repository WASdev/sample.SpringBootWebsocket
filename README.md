# Integrating a Spring Boot WebSocket Project with Liberty Using Maven

This tutorial demonstrates the entire process of modifying a sample Spring Boot WebSocket project to run as a packaged Liberty assembly. The end result is a standalone runnable JAR which contains the Websocket application deployed on a Liberty server.

We're going to be building off Spring Boot's "gs-messaging-stomp-websocket" [sample project](https://github.com/spring-guides/gs-messaging-stomp-websocket/). Spring Boot also provides a [guide on their website](https://spring.io/guides/gs/messaging-stomp-websocket/) which explains their project code in great detail.

### Table of Contents

* [Getting Started](#start)
* [Modifying the POM](#pom)
* [Server Configuration](#server)
* [Code Changes](#code)
* [Remaining Issues](#issues)

## <a name="start"></a>Getting Started

Start by downloading/cloning the code from Spring's "gs-messaging-stomp-websocket" [sample project](https://github.com/spring-guides/gs-messaging-stomp-websocket/). All the proceeding modifications will be made on the code in the ["complete" folder](https://github.com/spring-guides/gs-messaging-stomp-websocket/tree/master/complete) of that project. Thus, we suggest familiarizing yourself with that code and reading the guide before proceeding.

## <a name="pom"></a>Modifying the POM

We'll start by modifying the `pom.xml` in order to configure the project to run on a Liberty server. 

### Change the Packaging Type

First, set the packaging type to `liberty-assembly`. This can be added after the `version` parameter near the top of the file:

```
<packaging>liberty-assembly</packaging>
```

From our [Liberty Maven Plugin](https://github.com/WASdev/ci.maven) documentation:

> The `liberty-assembly` Maven packaging type is used to create a packaged Liberty profile server Maven artifact out of existing server installation, compressed archive, or another server Maven artifact. Any applications specified as Maven compile dependencies will be automatically packaged with the assembled server. Liberty features can also be installed and packaged with the assembled server.

### Add Liberty Dependencies

For this sample project, we'll be using Liberty (version 16.0.0.4) with Java EE 7 Web Profile. Add the following dependencies to get this Liberty runtime:

```
<dependencies>
	...
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
    </dependency>
    ...
</dependencies>
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

Perhaps most importantly, note the addition of the `<start-class>` property. We'll discuss this is greater detail in the [Code Changes](#code) section.

### Add Plugins

We'll need to add several new plugins to configure our WebSocket application to run properly on Liberty:

```
<plugins>
	...
	<plugin>
		<artifactId>maven-compiler-plugin</artifactId>
		<executions>
			<execution>
				<id>default-compile</id>
				<phase>compile</phase>
				<goals>
					<goal>compile</goal>
				</goals>
			</execution>
			<execution>
				<id>default-testCompile</id>
				<phase>test-compile</phase>
				<goals>
					<goal>testCompile</goal>
				</goals>
			</execution>
		</executions>
	</plugin>
	<plugin>
		<groupId>org.apache.maven.plugins</groupId>
		<artifactId>maven-war-plugin</artifactId>
		<configuration>
			<failOnMissingWebXml>false</failOnMissingWebXml>
			<packagingExcludes>pom.xml</packagingExcludes>
		</configuration>
		<executions>
			<execution>
				<id>war</id>
				<phase>prepare-package</phase>
				<goals>
					<goal>war</goal>
				</goals>
			</execution>
		</executions>
	</plugin>
	<plugin>
		<groupId>net.wasdev.wlp.maven.plugins</groupId>
		<artifactId>liberty-maven-plugin</artifactId>
		<version>1.3-SNAPSHOT</version>
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
		</configuration>
		<executions>
			<execution>
				<id>install-apps</id>
				<phase>prepare-package</phase>
				<goals>
					<goal>install-apps</goal>
				</goals>
				<configuration>
					<appsDirectory>apps</appsDirectory>
					<stripVersion>true</stripVersion>
					<installAppPackages>project</installAppPackages>
				</configuration>
			</execution>
		</executions>
	</plugin>
	<plugin>
		<groupId>org.apache.maven.plugins</groupId>
		<artifactId>maven-dependency-plugin</artifactId>
		<executions>
			<execution>
				<id>copy-server-files</id>
				<phase>package</phase>
				<goals>
					<goal>copy-dependencies</goal>
				</goals>
				<configuration>
					<includeArtifactIds>server-snippet</includeArtifactIds>
					<prependGroupId>true</prependGroupId>
					<outputDirectory>${project.build.directory}/wlp/usr/servers/${wlpServerName}/configDropins/defaults</outputDirectory>
				</configuration>
			</execution>
		</executions>
	</plugin>
	<plugin>
		<groupId>org.apache.maven.plugins</groupId>
		<artifactId>maven-resources-plugin</artifactId>
		<executions>
			<execution>
				<id>copy-app</id>
				<phase>package</phase>
				<goals>
					<goal>copy-resources</goal>
				</goals>
				<configuration>
					<outputDirectory>${project.build.directory}/wlp/usr/servers/${wlpServerName}/apps</outputDirectory>
					<resources>
						<resource>
							<directory>${project.build.directory}</directory>
							<includes>
								<include>${project.artifactId}-${project.version}.war</include>
							</includes>
						</resource>
					</resources>
				</configuration>
			</execution>
		</executions>
	</plugin>
	...
</plugins>
```

The following is a list of each plugin that we added, along with some comments:

* [maven-compiler-plugin](https://maven.apache.org/plugins/maven-compiler-plugin/): Unlike the `war` packaging type, the `liberty-assembly` packaging type does not compile the source by default, as it is meant to package existing Maven artifacts. Thus, we have to specify this manually. 
* [maven-war-plugin](https://maven.apache.org/plugins/maven-war-plugin/): Packages the source into a WAR. 
* [liberty-maven-plugin](https://github.com/WASdev/ci.maven#liberty-maven-plugin): Provides configuration for our Liberty server and application. Here, we create a server called "websocketServer" and use set the `packageFile` parameter to the desired file name and location of our packaged server. As per our `package-server` goal [guidelines](https://github.com/WASdev/ci.maven/blob/master/docs/package-server.md), we add `<include>runnable</include>` to the configuration to indicate that we want to package the server into a runnable JAR. Notice also that in our `install-apps` execution goal, we set `<appsDirectory>apps</appsDirectory>` to indicate that we want our application to be installed in the `apps` directory of the server rather than the default `dropins` directory. Note that this is an optional modification. 
* [maven-dependency-plugin](https://maven.apache.org/plugins/maven-dependency-plugin/): Copies application dependencies to the server.
* [maven-resources-plugin](https://maven.apache.org/plugins/maven-resources-plugin/): Copies application resources to the server.

## <a name="server"></a>Server Configuration

After modifying our POM, the next step is to create a `server.xml` file and add our server configuration. By default, this file should be located at `src/test/resources/server.xml`, although you can modify this by changing the `configFile` configuration parameter in the `liberty-maven-plugin` (we provide this code our example above, although it is commented out because we're using the default location for this sample project). 

Once you have created your `server.xml`, add the following code:

```
<?xml version="1.0" encoding="UTF-8"?>
<server description="new server">
	<application context-root="/"
		location="gs-messaging-stomp-websocket-0.1.0.war"></application>

	<!-- Enable features -->
	<featureManager>
		<feature>servlet-3.1</feature>
	</featureManager>

	<!-- To access this server from a remote client add a host attribute to 
		the following element, e.g. host="*" -->
	<httpEndpoint id="defaultHttpEndpoint" httpPort="9080"
		httpsPort="9443" />

	<!-- Automatically expand WAR files and EAR files -->
	<applicationManager autoExpand="true" />

</server>
```

There are a few notable things happening in this configuration:

* We set the context root of our application to the server root. This is done in order to maintain consistency with the file paths specified in the sample project, as Spring Boot applications running on embedded servers are located at the server root. 
* In our `featureManager`, we add the `servlet-3.1` Liberty feature as the application will be running as a servlet.
* We set `<applicationManager autoExpand="true" />` to automatically expand our WAR file. Note if you have the WDT (WebSphere Development Tools) plugin installed in Eclipse, you might see an error on this line. You can ignore this, as it will go away when `server.xml` is copied to the server.

## <a name="code"></a>Code Changes

We're now ready to make changes to our source code. This section is broken up by the type of changes we need to make.

### Startup Changes

We previously briefly mentioned the importance of setting the `<start-class>` parameter in the POM properties. The importance of this is evident now, as we're about to change how our WebSocket application is launched. 

Traditionally, a Spring Boot application running on an embedded server such as Tomcat simply calls `SpringApplication.run(...)` in its main class (in this case `hello.Application`). However, we must change this when deploying our application as a servlet to our Liberty server. Specifically, we're going to have our start class extend `SpringBootServletInitializer` in order to run our application as a WAR. Then, by setting this class as our `<start-class>` parameter, we specify (quite clearly) that our application starts its execution from this class. 

To make these changes, replace the original code in `Application.java` with the following:

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

### Checkpoint

If you've made it this far, you should done everything you need to successfully start your WebSocket application on a Liberty server. Take a minute to check whether you're on track. 

Start the application (by running `mvn install liberty:run-server`) and access its context root (`http://localhost:9080/`). You should see the static `index.html` page being displayed. This is good news; it means the server started up and has successfully loaded your application source.
 
However, you'll also notice (especially if you ran the project first as a Spring Boot standalone application) that the styling for the page is not correct. Additionally, the web socket is not actually functional, as the interface is not responsive. This is because there are some more changes you'll have to make for application to run properly when deployed as a WAR. 

### WebSocket and WebJars Configuration



## <a name="issues"></a>Remaining Issues

