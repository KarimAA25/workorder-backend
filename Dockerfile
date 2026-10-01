FROM eclipse-temurin:21-jdk AS build

WORKDIR /build

COPY . .

RUN chmod +x gradlew

# Make sure the runtime submodule was actually populated
RUN test -f runtime/conf/MoquiProductionConf.xml

# Get required Moqui components (no-op if already present under runtime/component)
RUN ./gradlew getComponent -Pcomponent=mantle-udm --no-daemon
RUN ./gradlew getComponent -Pcomponent=mantle-usl --no-daemon
RUN ./gradlew getComponent -Pcomponent=SimpleScreens --no-daemon

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