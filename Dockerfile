FROM eclipse-temurin:21-jdk AS build

WORKDIR /build

COPY . .

RUN chmod +x gradlew

# Make sure the runtime submodule was actually populated
RUN test -f runtime/conf/MoquiProductionConf.xml

# Get required Moqui components. mantle-udm/mantle-usl/SimpleScreens are nested git
# submodules inside the runtime fork with no runtime/.gitmodules to resolve them, so a
# fresh submodule clone (e.g. Render's) leaves them as empty gitlink placeholders.
# getComponent's own "already exists" check would silently treat that empty dir as done
# and skip the download, so force a clean fetch here instead of trusting what COPY brought in.
RUN rm -rf runtime/component/mantle-udm runtime/component/mantle-usl runtime/component/SimpleScreens
RUN ./gradlew getComponent -Pcomponent=mantle-udm --no-daemon
RUN ./gradlew getComponent -Pcomponent=mantle-usl --no-daemon
RUN ./gradlew getComponent -Pcomponent=SimpleScreens --no-daemon

# Fail the build loudly here instead of shipping a WAR that crashes at startup
RUN test -f runtime/component/mantle-udm/component.xml \
    && test -f runtime/component/mantle-usl/component.xml \
    && test -f runtime/component/SimpleScreens/component.xml

# Package framework + runtime + components
RUN ./gradlew addRuntime --no-daemon


FROM eclipse-temurin:21-jdk

WORKDIR /opt/moqui

# Extract the executable WAR
COPY --from=build /build/moqui-plus-runtime.war .
RUN apt-get update \
    && apt-get install -y unzip \
    && unzip -q moqui-plus-runtime.war \
    && rm moqui-plus-runtime.war \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Explicitly provide the runtime directory as well
COPY --from=build /build/runtime /opt/moqui/runtime

EXPOSE 10000

ENTRYPOINT ["java", "-cp", ".", "MoquiStart"]
CMD ["conf=conf/MoquiProductionConf.xml", "port=10000"]