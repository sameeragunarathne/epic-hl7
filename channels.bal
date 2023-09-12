import ballerinax/health.hl7v23;

function outgoingAppointmentSchedulingChannel(hl7v23:SIU_S12 appointment) returns hl7v23:SIU_S12|anydata {
    //implement outgoing appointment scheduling logic. 
    // If datamapping is required, implement it here and return the mapped message.
};


function incomingAppointmentSchedulingChannel(hl7v23:SIU_S12 appointment) returns hl7v23:SIU_S12|anydata {
    //implement incoming appointment scheduling logic. 
    // If datamapping is required, implement it here and return the mapped message.
};