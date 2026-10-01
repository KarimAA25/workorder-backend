FROM eclipse-temurin:21-jdk AS build

WORKDIR /build

COPY . .

RUN chmod +x gradlew
RUN ./gradlew addRuntime --no-daemon


FROM eclipse-temurin:21-jdk

WORKDIR /opt/moqui

COPY --from=build /build/moqui-plus-runtime.war .

RUN apt-get update \
    && apt-get install -y unzip \
    && unzip -q moqui-plus-runtime.war \
    && rm moqui-plus-runtime.war \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 10000

ENTRYPOINT ["java", "-cp", ".", "MoquiStart"]
CMD ["conf=conf/MoquiProductionConf.xml", "port=10000"]