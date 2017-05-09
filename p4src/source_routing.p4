/*
Copyright 2013-present Barefoot Networks, Inc. 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

header_type easyroute_head_t {
    fields {
        preamble: 64;
        priority_val: 16;
        enq_qdepth: 16;
        deq_qdepth: 16;
        num_valid: 32;
    }
}

header easyroute_head_t easyroute_head;

header_type easyroute_port_t {
    fields {
        port: 8;
    }
}

header easyroute_port_t easyroute_port;

header_type queueing_metadata_t {
    fields {
        enq_timestamp : 48;
        enq_qdepth : 16;
        deq_timedelta : 32;
        deq_qdepth : 16;
    }
}
metadata queueing_metadata_t queueing_metadata;

header_type intrinsic_metadata_t {
    fields {
		mcast_grp : 4;
		egress_rid : 4;
		mcast_hash : 16;
		lf_field_list: 32;
		ingress_global_timestamp : 48;
		priority : 8;
    }
}
metadata intrinsic_metadata_t intrinsic_metadata;

parser start {
    return select(current(0, 64)) {
        0: parse_head;
        default: ingress;
    }
}

parser parse_head {
    extract(easyroute_head);
    return select(latest.num_valid) {
        0: ingress;
        default: parse_port;
    }
}

parser parse_port {
    extract(easyroute_port);
    return ingress;
}

action _drop() {
    drop();
}

action route() {
    modify_field(standard_metadata.egress_spec, easyroute_port.port);
    modify_field(intrinsic_metadata.priority, easyroute_head.priority_val);
    modify_field(easyroute_head.priority_val, intrinsic_metadata.priority);
    add_to_field(easyroute_head.num_valid, -1);
    remove_header(easyroute_port);
}

action get_info() {
    modify_field(easyroute_head.enq_qdepth, queueing_metadata.enq_qdepth);
    modify_field(easyroute_head.deq_qdepth, queueing_metadata.deq_qdepth);
}

table route_pkt {
    reads {
        easyroute_port: valid;
    }
    actions {
        _drop;
        route;
    }
    size: 1;
}

table get_switch_info {
    reads {
        easyroute_head: valid;
    }
    actions {
        get_info;
    }
    size: 1;
}


control ingress {
    apply(route_pkt);
}

control egress {
    apply(get_switch_info);
    // leave empty
}
