import ballerina/io;
import ballerina/tcp;
import ballerina/log;

import ballerinax/health.hl7v2 as hl7;
import ballerinax/health.hl7v23;

configurable string sendingAppName = "HIS";
configurable string receivingAppName = "EPIC";
configurable record {|
    string protocol;
    string host;
    int port;
|} connectionConfig = {
    protocol: "hl7v2",
    host: "localhost",
    port: 59519
};

service on new tcp:Listener(9090) {

    // This remote method is invoked when the new client connects to the server.
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        io:println("Client connected to hl7 service: ", caller.remotePort);
        return new HL7Service();
    }
}

service class HL7Service {
    *tcp:ConnectionService;

    // This remote method is invoked once the content is received from the client.
    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {
        string|error fromBytes = string:fromBytes(data);
        if fromBytes is string {
            do {
                hl7:Message message = check hl7:parse(fromBytes);
                if message is hl7v23:SIU_S12 {
                    hl7v23:SIU_S12 appointment = message;
                    hl7:Message|hl7:HL7Error|error? result = appointmentScheduling(appointment);
                    if result is hl7:Message {
                        //send the result to the client
                        byte[]|hl7:HL7Error encode = hl7:encode(hl7v23:VERSION, result);
                        if encode is byte[] {
                            check caller->writeBytes(data);
                        }
                    } else {
                        //todo: create ack message and send to client
                    }
                }
            } on fail var e {
                log:printError("Error occurred while parsing the message", e);
            }
        }
        check caller->writeBytes(data);
    }

    // This remote method is invoked in an erroneous situation,
    // which occurs during the execution of the `onConnect` or `onBytes` method.
    remote function onError(tcp:Error err) {
        log:printError("An error occurred", 'error = err);
    }

    // This remote method is invoked when the connection is closed.
    remote function onClose() {
        io:println("Client left");
    }
}

function appointmentScheduling(hl7v23:SIU_S12|hl7v23:SRM_S01 appointment) returns hl7:Message|hl7:HL7Error|error? {
    hl7v23:MSH? msh = appointment.msh;
    if msh is hl7v23:MSH {
        hl7v23:HD sendingApp = msh.msh3;
        hl7v23:HD receivingApp = msh.msh5;

        if sendingApp.hd1 == sendingAppName && receivingApp.hd1 == receivingAppName {
            //process and send to epic as incoming appointment scheduling
            hl7v23:SIU_S12|anydata incomingAppointmentSchedulingResult = incomingAppointmentSchedulingChannel(appointment);
            if incomingAppointmentSchedulingResult is hl7v23:SIU_S12 {
                //send to epic
                hl7:HL7Client hl7Client = check new (connectionConfig.host, connectionConfig.port);
                return hl7Client.sendMessage(incomingAppointmentSchedulingResult);
            } else {
                //todo: handle error. Here we only support hl7 messages to Epic
            }
        } else if sendingApp.hd1 == "EPIC" && receivingApp.hd1 == "HIS" {
            //process and send to HIS as outgoing appointment scheduling
            hl7v23:SIU_S12|anydata outgoingAppointmentSchedulingResult = outgoingAppointmentSchedulingChannel(appointment);
            if outgoingAppointmentSchedulingResult is hl7v23:SIU_S12 {
                //send to HIS
                hl7:HL7Client hl7Client = check new (connectionConfig.host, connectionConfig.port);
                return hl7Client.sendMessage(outgoingAppointmentSchedulingResult);
            } else {
                //todo: implement a connection object to send the message constructed for the expected protocol
            }
        }
    }
};
