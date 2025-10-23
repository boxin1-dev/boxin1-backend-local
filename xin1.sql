--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: command_status_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.command_status_enum AS ENUM (
    'pending',
    'sent',
    'acknowledged',
    'failed',
    'timeout'
);


ALTER TYPE public.command_status_enum OWNER TO admin;

--
-- Name: device_status_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.device_status_enum AS ENUM (
    'normal',
    'error',
    'maintenance',
    'standby'
);


ALTER TYPE public.device_status_enum OWNER TO admin;

--
-- Name: door_state_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.door_state_enum AS ENUM (
    'open',
    'closed'
);


ALTER TYPE public.door_state_enum OWNER TO admin;

--
-- Name: event_type_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.event_type_enum AS ENUM (
    'discovery',
    'connection',
    'disconnection',
    'command',
    'error',
    'warning',
    'info'
);


ALTER TYPE public.event_type_enum OWNER TO admin;

--
-- Name: execution_status_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.execution_status_enum AS ENUM (
    'success',
    'failed',
    'partial'
);


ALTER TYPE public.execution_status_enum OWNER TO admin;

--
-- Name: quality_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.quality_enum AS ENUM (
    'good',
    'bad',
    'uncertain',
    'timeout'
);


ALTER TYPE public.quality_enum OWNER TO admin;

--
-- Name: setting_type_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.setting_type_enum AS ENUM (
    'string',
    'integer',
    'boolean',
    'json'
);


ALTER TYPE public.setting_type_enum OWNER TO admin;

--
-- Name: severity_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.severity_enum AS ENUM (
    'low',
    'medium',
    'high',
    'critical'
);


ALTER TYPE public.severity_enum OWNER TO admin;

--
-- Name: trigger_type_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.trigger_type_enum AS ENUM (
    'time',
    'device_state',
    'manual',
    'webhook'
);


ALTER TYPE public.trigger_type_enum OWNER TO admin;

--
-- Name: user_role_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.user_role_enum AS ENUM (
    'admin',
    'user',
    'guest'
);


ALTER TYPE public.user_role_enum OWNER TO admin;

--
-- Name: value_type_enum; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.value_type_enum AS ENUM (
    'boolean',
    'integer',
    'float',
    'string',
    'color'
);


ALTER TYPE public.value_type_enum OWNER TO admin;

--
-- Name: cleanup_old_data(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.cleanup_old_data() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    retention_days INTEGER := 365;
BEGIN
    -- Récupérer la durée de rétention
    SELECT setting_value::INTEGER INTO retention_days 
    FROM system_settings WHERE setting_key = 'history_retention_days';
    
    -- Nettoyer l'historique ancien
    DELETE FROM capability_history 
    WHERE timestamp < NOW() - INTERVAL '1 day' * retention_days;
    
    -- Nettoyer les événements anciens (garder 90 jours)
    DELETE FROM system_events 
    WHERE timestamp < NOW() - INTERVAL '90 days' AND severity IN ('low', 'medium');
    
    -- Nettoyer les commandes anciennes (garder 30 jours)
    DELETE FROM device_commands 
    WHERE created_at < NOW() - INTERVAL '30 days' AND status IN ('acknowledged', 'failed');
    
END;
$$;


ALTER FUNCTION public.cleanup_old_data() OWNER TO admin;

--
-- Name: register_smartbox_device(character varying, character varying, character varying, text, text, character varying, jsonb); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.register_smartbox_device(p_device_id character varying, p_device_name character varying, p_device_type_code character varying, p_ip_address text, p_mac_address text, p_firmware_version character varying, p_capabilities jsonb DEFAULT NULL::jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    device_pk INTEGER;
    default_location INTEGER;
    auto_assign_location BOOLEAN := FALSE;
BEGIN
    -- Récupérer les paramètres système
    SELECT setting_value::INTEGER INTO default_location 
    FROM system_settings WHERE setting_key = 'default_location_id';
    
    SELECT setting_value::BOOLEAN INTO auto_assign_location
    FROM system_settings WHERE setting_key = 'auto_assign_location';
    
    -- Insérer ou mettre à jour l'appareil
    INSERT INTO smartbox_devices (
        device_id, device_name, device_type_code, 
        location_id, ip_address, mac_address, firmware_version,
        discovery_topic, command_topic, status_topic,
        is_online, last_discovery
    ) VALUES (
        p_device_id, p_device_name, p_device_type_code,
        CASE WHEN auto_assign_location THEN default_location ELSE NULL END,
        p_ip_address::INET, p_mac_address::MACADDR, p_firmware_version,
        'smartbox/discovery/' || p_device_id,
        'smartbox/' || p_device_id || '/cmd',
        'smartbox/' || p_device_id || '/status',
        TRUE, NOW()
    ) ON CONFLICT (device_id) DO UPDATE SET
        device_name = EXCLUDED.device_name,
        ip_address = EXCLUDED.ip_address,
        mac_address = EXCLUDED.mac_address,
        firmware_version = EXCLUDED.firmware_version,
        is_online = TRUE,
        last_discovery = NOW(),
        last_seen = NOW();
    
    -- Récupérer l'ID de l'appareil
    SELECT id INTO device_pk FROM smartbox_devices WHERE device_id = p_device_id;
    
    -- Log de l'événement
    INSERT INTO system_events (event_type, device_id, title, description, event_data)
    VALUES ('discovery', device_pk, 'Appareil découvert', 
            'Nouvel appareil SmartBox: ' || p_device_name, p_capabilities);
    
    RETURN device_pk;
END;
$$;


ALTER FUNCTION public.register_smartbox_device(p_device_id character varying, p_device_name character varying, p_device_type_code character varying, p_ip_address text, p_mac_address text, p_firmware_version character varying, p_capabilities jsonb) OWNER TO admin;

--
-- Name: update_capability_value(character varying, character varying, text, public.quality_enum); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.update_capability_value(p_device_id character varying, p_capability_code character varying, p_value text, p_quality public.quality_enum DEFAULT 'good'::public.quality_enum) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    capability_pk INTEGER;
    device_pk INTEGER;
BEGIN
    -- Récupérer les IDs
    SELECT d.id, dc.id INTO device_pk, capability_pk
    FROM smartbox_devices d
    JOIN device_capabilities dc ON d.id = dc.device_id
    WHERE d.device_id = p_device_id AND dc.capability_code = p_capability_code;
    
    IF capability_pk IS NOT NULL THEN
        -- Mettre à jour la valeur actuelle
        UPDATE device_capabilities 
        SET current_value = p_value, last_updated = NOW()
        WHERE id = capability_pk;
        
        -- Ajouter à l'historique
        INSERT INTO capability_history (device_capability_id, value, timestamp, quality)
        VALUES (capability_pk, p_value, NOW(), COALESCE(p_quality, 'good'));
        
        -- Mettre à jour le last_seen de l'appareil
        UPDATE smartbox_devices 
        SET last_seen = NOW(), is_online = TRUE
        WHERE id = device_pk;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$;


ALTER FUNCTION public.update_capability_value(p_device_id character varying, p_capability_code character varying, p_value text, p_quality public.quality_enum) OWNER TO admin;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                BEGIN
                    NEW.updated_at = NOW();
                    RETURN NEW;
                END;
                $$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: automation_scenarios; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.automation_scenarios (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    trigger_type public.trigger_type_enum NOT NULL,
    trigger_config jsonb NOT NULL,
    actions jsonb NOT NULL,
    conditions jsonb,
    execution_count integer DEFAULT 0,
    last_execution timestamp without time zone,
    last_execution_status public.execution_status_enum,
    created_by character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.automation_scenarios OWNER TO admin;

--
-- Name: automation_scenarios_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.automation_scenarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.automation_scenarios_id_seq OWNER TO admin;

--
-- Name: automation_scenarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.automation_scenarios_id_seq OWNED BY public.automation_scenarios.id;


--
-- Name: capability_history; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.capability_history (
    id bigint NOT NULL,
    device_capability_id integer NOT NULL,
    value text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    quality public.quality_enum DEFAULT 'good'::public.quality_enum,
    source character varying(100) DEFAULT 'mqtt'::character varying
);


ALTER TABLE public.capability_history OWNER TO admin;

--
-- Name: capability_history_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.capability_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.capability_history_id_seq OWNER TO admin;

--
-- Name: capability_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.capability_history_id_seq OWNED BY public.capability_history.id;


--
-- Name: capability_types; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.capability_types (
    id integer NOT NULL,
    capability_code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    value_type public.value_type_enum NOT NULL,
    unit character varying(20),
    min_value numeric(15,6),
    max_value numeric(15,6),
    allowed_values jsonb,
    is_readable boolean DEFAULT true,
    is_writable boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.capability_types OWNER TO admin;

--
-- Name: capability_types_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.capability_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.capability_types_id_seq OWNER TO admin;

--
-- Name: capability_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.capability_types_id_seq OWNED BY public.capability_types.id;


--
-- Name: device_capabilities; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.device_capabilities (
    id integer NOT NULL,
    device_id integer NOT NULL,
    capability_code character varying(50) NOT NULL,
    capability_name character varying(100) NOT NULL,
    description text,
    state_topic character varying(255) NOT NULL,
    current_value text,
    last_updated timestamp without time zone,
    is_visible boolean DEFAULT true,
    display_order integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    capability_type_id integer
);


ALTER TABLE public.device_capabilities OWNER TO admin;

--
-- Name: device_capabilities_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.device_capabilities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_capabilities_id_seq OWNER TO admin;

--
-- Name: device_capabilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.device_capabilities_id_seq OWNED BY public.device_capabilities.id;


--
-- Name: device_commands; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.device_commands (
    id integer NOT NULL,
    device_id integer NOT NULL,
    capability_code character varying(50),
    command_name character varying(100) NOT NULL,
    command_value text NOT NULL,
    status public.command_status_enum DEFAULT 'pending'::public.command_status_enum,
    sent_at timestamp without time zone,
    response_received_at timestamp without time zone,
    response_data jsonb,
    error_message text,
    initiated_by character varying(100),
    source_ip inet,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.device_commands OWNER TO admin;

--
-- Name: device_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.device_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_commands_id_seq OWNER TO admin;

--
-- Name: device_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.device_commands_id_seq OWNED BY public.device_commands.id;


--
-- Name: device_types; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.device_types (
    id integer NOT NULL,
    type_code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    icon character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.device_types OWNER TO admin;

--
-- Name: device_types_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.device_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.device_types_id_seq OWNER TO admin;

--
-- Name: device_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.device_types_id_seq OWNED BY public.device_types.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.locations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    floor_level integer DEFAULT 0,
    area_m2 numeric(8,2),
    icon character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.locations OWNER TO admin;

--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.locations_id_seq OWNER TO admin;

--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: smartbox_devices; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.smartbox_devices (
    id integer NOT NULL,
    device_id character varying(100) NOT NULL,
    device_name character varying(200) NOT NULL,
    device_type_code character varying(50) NOT NULL,
    location_id integer,
    ip_address inet,
    mac_address macaddr,
    firmware_version character varying(50),
    manufacturer character varying(100) DEFAULT 'SmartBox'::character varying,
    discovery_topic character varying(255) NOT NULL,
    command_topic character varying(255) NOT NULL,
    status_topic character varying(255) NOT NULL,
    is_online boolean DEFAULT false,
    last_seen timestamp without time zone,
    last_discovery timestamp without time zone NOT NULL,
    connection_quality integer,
    is_enabled boolean DEFAULT true,
    user_notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    device_type_id integer
);


ALTER TABLE public.smartbox_devices OWNER TO admin;

--
-- Name: smartbox_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.smartbox_devices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.smartbox_devices_id_seq OWNER TO admin;

--
-- Name: smartbox_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.smartbox_devices_id_seq OWNED BY public.smartbox_devices.id;


--
-- Name: system_events; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.system_events (
    id bigint NOT NULL,
    event_type public.event_type_enum NOT NULL,
    device_id integer,
    title character varying(200) NOT NULL,
    description text,
    event_data jsonb,
    severity public.severity_enum DEFAULT 'low'::public.severity_enum,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.system_events OWNER TO admin;

--
-- Name: system_events_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.system_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_events_id_seq OWNER TO admin;

--
-- Name: system_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.system_events_id_seq OWNED BY public.system_events.id;


--
-- Name: system_settings; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.system_settings (
    id integer NOT NULL,
    setting_key character varying(100) NOT NULL,
    setting_value text,
    setting_type public.setting_type_enum DEFAULT 'string'::public.setting_type_enum,
    description text,
    is_user_configurable boolean DEFAULT true,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.system_settings OWNER TO admin;

--
-- Name: system_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.system_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_settings_id_seq OWNER TO admin;

--
-- Name: system_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.system_settings_id_seq OWNED BY public.system_settings.id;


--
-- Name: v_controllable_capabilities; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.v_controllable_capabilities AS
 SELECT dc.id,
    d.device_id,
    d.device_name,
    dc.capability_code,
    dc.capability_name,
    ct.value_type,
    ct.unit,
    ct.min_value,
    ct.max_value,
    ct.allowed_values,
    dc.current_value,
    dc.state_topic
   FROM ((public.device_capabilities dc
     JOIN public.smartbox_devices d ON ((dc.device_id = d.id)))
     JOIN public.capability_types ct ON ((dc.capability_type_id = ct.id)))
  WHERE ((d.is_enabled = true) AND (dc.is_visible = true) AND (ct.is_writable = true) AND (d.is_online = true));


ALTER VIEW public.v_controllable_capabilities OWNER TO admin;

--
-- Name: v_device_capabilities_complete; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.v_device_capabilities_complete AS
 SELECT dc.id,
    d.device_id,
    d.device_name,
    dt.name AS device_type_name,
    dc.capability_code,
    dc.capability_name,
    ct.name AS capability_type_name,
    ct.description AS capability_description,
    ct.value_type,
    ct.unit,
    ct.min_value,
    ct.max_value,
    ct.allowed_values,
    ct.is_readable,
    ct.is_writable,
    dc.current_value,
    dc.last_updated,
    dc.state_topic,
    dc.is_visible,
    dc.display_order
   FROM (((public.device_capabilities dc
     JOIN public.smartbox_devices d ON ((dc.device_id = d.id)))
     JOIN public.device_types dt ON ((d.device_type_id = dt.id)))
     LEFT JOIN public.capability_types ct ON ((dc.capability_type_id = ct.id)))
  WHERE ((d.is_enabled = true) AND (dc.is_visible = true))
  ORDER BY d.device_name, dc.display_order, dc.capability_name;


ALTER VIEW public.v_device_capabilities_complete OWNER TO admin;

--
-- Name: v_devices_complete; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.v_devices_complete AS
 SELECT d.id,
    d.device_id,
    d.device_name,
    dt.name AS device_type_name,
    dt.type_code,
    dt.icon AS device_icon,
    l.name AS location_name,
    d.ip_address,
    d.mac_address,
    d.firmware_version,
    d.is_online,
    d.last_seen,
    d.last_discovery,
    d.is_enabled
   FROM ((public.smartbox_devices d
     LEFT JOIN public.device_types dt ON ((d.device_type_id = dt.id)))
     LEFT JOIN public.locations l ON ((d.location_id = l.id)));


ALTER VIEW public.v_devices_complete OWNER TO admin;

--
-- Name: v_recent_events; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.v_recent_events AS
 SELECT e.id,
    e.event_type,
    e.title,
    e.description,
    e.severity,
    e."timestamp",
    d.device_name,
    d.device_id
   FROM (public.system_events e
     LEFT JOIN public.smartbox_devices d ON ((e.device_id = d.id)))
  WHERE (e."timestamp" >= (now() - '7 days'::interval))
  ORDER BY e."timestamp" DESC;


ALTER VIEW public.v_recent_events OWNER TO admin;

--
-- Name: automation_scenarios id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.automation_scenarios ALTER COLUMN id SET DEFAULT nextval('public.automation_scenarios_id_seq'::regclass);


--
-- Name: capability_history id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_history ALTER COLUMN id SET DEFAULT nextval('public.capability_history_id_seq'::regclass);


--
-- Name: capability_types id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_types ALTER COLUMN id SET DEFAULT nextval('public.capability_types_id_seq'::regclass);


--
-- Name: device_capabilities id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_capabilities ALTER COLUMN id SET DEFAULT nextval('public.device_capabilities_id_seq'::regclass);


--
-- Name: device_commands id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_commands ALTER COLUMN id SET DEFAULT nextval('public.device_commands_id_seq'::regclass);


--
-- Name: device_types id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_types ALTER COLUMN id SET DEFAULT nextval('public.device_types_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: smartbox_devices id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.smartbox_devices ALTER COLUMN id SET DEFAULT nextval('public.smartbox_devices_id_seq'::regclass);


--
-- Name: system_events id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_events ALTER COLUMN id SET DEFAULT nextval('public.system_events_id_seq'::regclass);


--
-- Name: system_settings id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_settings ALTER COLUMN id SET DEFAULT nextval('public.system_settings_id_seq'::regclass);


--
-- Data for Name: automation_scenarios; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.automation_scenarios (id, name, description, is_active, trigger_type, trigger_config, actions, conditions, execution_count, last_execution, last_execution_status, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: capability_history; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.capability_history (id, device_capability_id, value, "timestamp", quality, source) FROM stdin;
1	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-26 10:02:02.636171	good	mqtt
2	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-26 10:43:43.874199	good	mqtt
3	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-26 14:32:16.664263	good	mqtt
4	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-26 14:33:41.579753	good	mqtt
5	1	true	2025-08-26 14:50:06.754759	good	mqtt
6	11	22.5	2025-08-26 14:52:43.084437	good	mqtt
7	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6550}	2025-08-26 16:36:32.250587	good	mqtt
8	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6569}	2025-08-26 16:37:02.234883	good	mqtt
9	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6660}	2025-08-26 16:38:52.738389	good	mqtt
10	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":9510}	2025-08-26 16:40:21.294231	good	mqtt
11	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-26 16:47:16.914154	good	mqtt
12	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-26 16:47:39.936539	good	mqtt
13	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-27 07:44:43.464496	good	mqtt
14	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-27 07:44:46.85469	good	mqtt
15	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-27 12:00:55.860965	good	mqtt
16	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-27 12:00:55.985033	good	mqtt
17	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-27 13:15:32.943166	good	mqtt
18	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-27 13:15:33.011795	good	mqtt
19	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-27 16:00:52.643337	good	mqtt
20	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-27 16:00:52.665082	good	mqtt
21	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-28 08:05:11.418494	good	mqtt
22	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7604}	2025-08-28 08:05:11.43311	good	mqtt
23	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6635}	2025-08-28 17:18:13.994979	good	mqtt
24	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6582}	2025-08-28 17:23:41.772201	good	mqtt
25	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6545}	2025-08-28 17:44:58.502282	good	mqtt
26	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-30 10:52:20.968465	good	mqtt
27	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":10199}	2025-08-30 10:52:20.975988	good	mqtt
28	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":709150}	2025-08-30 10:52:20.984803	good	mqtt
29	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6599}	2025-08-30 11:01:45.94848	good	mqtt
30	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6565}	2025-08-30 14:26:58.701691	good	mqtt
31	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6594}	2025-08-30 14:28:33.452715	good	mqtt
32	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-08-30 15:37:45.589265	good	mqtt
33	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6594}	2025-08-30 15:37:45.598735	good	mqtt
34	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":709150}	2025-08-30 15:37:45.607127	good	mqtt
35	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6521}	2025-08-30 15:44:32.291141	good	mqtt
36	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":7237}	2025-08-30 15:57:43.503466	good	mqtt
37	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":6580}	2025-08-30 16:07:36.313314	good	mqtt
38	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":8631}	2025-09-01 10:49:18.168019	good	mqtt
39	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":8695}	2025-09-01 10:51:22.246301	good	mqtt
40	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-01 10:55:50.885101	good	mqtt
41	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-09-03 08:31:02.492733	good	mqtt
42	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-03 08:31:02.497948	good	mqtt
43	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-03 08:31:02.507309	good	mqtt
44	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-03 08:31:02.516584	good	mqtt
45	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-03 08:31:02.519505	good	mqtt
46	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-09-03 16:41:46.672075	good	mqtt
47	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-03 16:41:46.682194	good	mqtt
48	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-03 16:41:46.68552	good	mqtt
49	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-03 16:41:46.698603	good	mqtt
50	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-03 16:41:46.701247	good	mqtt
51	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-09-04 08:49:43.678695	good	mqtt
52	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-04 08:49:43.688971	good	mqtt
53	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-04 08:49:43.691751	good	mqtt
54	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-04 08:49:43.694888	good	mqtt
55	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-04 08:49:43.697397	good	mqtt
56	1	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-09-04 15:49:52.604653	good	mqtt
57	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-04 15:49:52.617313	good	mqtt
58	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-04 15:49:52.620275	good	mqtt
59	9	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-04 15:49:52.623977	good	mqtt
60	8	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-04 15:49:52.626548	good	mqtt
\.


--
-- Data for Name: capability_types; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.capability_types (id, capability_code, name, description, value_type, unit, min_value, max_value, allowed_values, is_readable, is_writable, created_at) FROM stdin;
13	power	Alimentation	État marche/arrêt de l'appareil	boolean		\N	\N	\N	t	t	2025-08-26 15:07:57.083042
14	brightness	Luminosité	Niveau de luminosité en pourcentage	integer	%	0.000000	100.000000	\N	t	t	2025-08-26 15:07:57.083042
16	temperature	Température	Température en degrés Celsius	float	°C	-50.000000	100.000000	\N	t	t	2025-08-26 15:07:57.083042
17	humidity	Humidité	Taux d'humidité relative	float	%	0.000000	100.000000	\N	t	f	2025-08-26 15:07:57.083042
18	timer	Minuteur	Timer en minutes	integer	min	0.000000	1440.000000	\N	t	t	2025-08-26 15:07:57.083042
19	speed	Vitesse	Vitesse de rotation ou niveau	integer	%	0.000000	100.000000	\N	t	t	2025-08-26 15:07:57.083042
20	volume	Volume	Niveau sonore	integer	%	0.000000	100.000000	\N	t	t	2025-08-26 15:07:57.083042
21	motion	Détection Mouvement	Présence détectée	boolean		\N	\N	\N	t	f	2025-08-26 15:07:57.083042
22	door	État Porte	Porte ouverte/fermée	string		\N	\N	\N	t	f	2025-08-26 15:07:57.083042
23	power_consumption	Consommation	Consommation électrique	float	W	0.000000	10000.000000	\N	t	f	2025-08-26 15:07:57.083042
24	status	Statut	État général de l'appareil	string		\N	\N	\N	t	f	2025-08-26 15:07:57.083042
15	color	Couleur	Couleur RGB ou nom de couleur	color		0.000000	255.000000	\N	t	t	2025-08-26 15:07:57.083042
\.


--
-- Data for Name: device_capabilities; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.device_capabilities (id, device_id, capability_code, capability_name, description, state_topic, current_value, last_updated, is_visible, display_order, created_at, updated_at, capability_type_id) FROM stdin;
9	4	brightness	brightness	Luminosité	smartbox/lamp_salon_02/state/brightness	{"device_id":"lamp_salon_02","capability":"brightness","value":"20","timestamp":13607}	2025-09-04 15:49:52.623977	t	0	2025-08-26 14:34:38.687948	2025-09-04 15:49:52.623977	14
8	4	power	power	Allumer/Éteindre la lampe	smartbox/lamp_salon_02/state/power	{"device_id":"lamp_salon_02","capability":"power","value":"off","timestamp":1030585}	2025-09-04 15:49:52.626548	t	0	2025-08-26 14:34:38.685076	2025-09-04 15:49:52.626548	13
3	1	brightness	Luminosité	Niveau de luminosité	smartbox/lamp_salon_01/state/brightness	\N	\N	t	0	2025-08-26 14:32:16.654324	2025-09-03 17:34:11.156135	14
11	5	temperature	Température	Température ambiante	smartbox/thermo_cuisine_01/state/temperature	22.5	2025-08-26 14:52:43.084437	t	0	2025-08-26 14:45:44.962325	2025-09-03 17:34:11.156135	16
12	5	humidity	Humidité	Humidité relative	smartbox/thermo_cuisine_01/state/humidity	\N	\N	t	0	2025-08-26 14:45:44.975159	2025-09-03 17:34:11.156135	17
15	4	status	status	Rapport de statut	smartbox/lamp_salon_02/state/status	\N	\N	t	0	2025-09-03 08:31:02.476921	2025-09-03 17:34:11.156135	24
4	1	color	Couleur	Couleur RGB	smartbox/lamp_salon_01/state/color	\N	\N	t	0	2025-08-26 14:32:16.65764	2025-09-03 17:34:11.156135	15
10	4	color	Couleur	Couleur RGB	smartbox/lamp_salon_02/state/color	\N	\N	t	0	2025-08-26 14:34:38.690918	2025-09-03 17:34:11.156135	15
1	1	power	Alimentation	État marche/arrêt	smartbox/lamp_salon_01/state/power	{"device_id":"lamp_salon_01","capability":"power","value":"off","timestamp":269625}	2025-09-04 15:49:52.604653	t	0	2025-08-26 10:02:02.591164	2025-09-04 15:49:52.604653	13
\.


--
-- Data for Name: device_commands; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.device_commands (id, device_id, capability_code, command_name, command_value, status, sent_at, response_received_at, response_data, error_message, initiated_by, source_ip, created_at) FROM stdin;
\.


--
-- Data for Name: device_types; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.device_types (id, type_code, name, description, icon, created_at) FROM stdin;
19	lamp	Lampe Connectée	Éclairage intelligent avec contrôle de luminosité	lightbulb	2025-08-26 14:13:57.69853
20	thermometer	Thermomètre	Capteur de température et humidité	thermometer	2025-08-26 14:13:57.69853
21	fridge	Réfrigérateur	Électroménager réfrigération	kitchen	2025-08-26 14:13:57.69853
22	oven	Four	Four intelligent avec contrôle température et timer	oven	2025-08-26 14:13:57.69853
23	fan	Ventilateur	Ventilateur avec contrôle de vitesse	fan	2025-08-26 14:13:57.69853
24	heater	Radiateur	Chauffage intelligent	heater	2025-08-26 14:13:57.69853
25	door_sensor	Capteur de Porte	Détecteur d'ouverture/fermeture	door	2025-08-26 14:13:57.69853
26	motion_sensor	Détecteur de Mouvement	Capteur de présence	motion	2025-08-26 14:13:57.69853
27	custom	Appareil Personnalisé	Appareil avec capacités personnalisées	device	2025-08-26 14:13:57.69853
\.


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.locations (id, name, description, floor_level, area_m2, icon, created_at) FROM stdin;
\.


--
-- Data for Name: smartbox_devices; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.smartbox_devices (id, device_id, device_name, device_type_code, location_id, ip_address, mac_address, firmware_version, manufacturer, discovery_topic, command_topic, status_topic, is_online, last_seen, last_discovery, connection_quality, is_enabled, user_notes, created_at, updated_at, device_type_id) FROM stdin;
4	lamp_salon_02	Lampe Salon	lamp	\N	192.168.1.170	50:02:91:46:29:3f	1.0.0	SmartBox	smartbox/discovery/lamp_salon_02	smartbox/lamp_salon_02/cmd	smartbox/lamp_salon_02/status	f	2025-09-04 15:49:52.62637	2025-09-04 15:49:52.575922	\N	t	\N	2025-08-26 14:34:38.681189	2025-09-04 16:59:57.595612	19
1	lamp_salon_01	lamp cuisine	lamp	\N	192.168.1.150	aa:bb:cc:dd:ee:01	1.2.3	SmartBox	smartbox/discovery/lamp_salon_01	smartbox/lamp_salon_01/cmd	smartbox/lamp_salon_01/status	f	2025-09-04 15:49:52.60422	2025-08-26 14:33:41.560795	\N	t	\N	2025-08-26 10:02:02.55262	2025-09-04 16:59:57.610744	19
5	thermo_cuisine_01	Thermomètre Cuisine	thermometer	\N	192.168.1.151	aa:aa:cc:dd:ee:02	2.1.0	SmartBox	smartbox/discovery/thermo_cuisine_01	smartbox/thermo_cuisine_01/cmd	smartbox/thermo_cuisine_01/status	f	2025-08-26 14:52:43.08408	2025-08-26 14:45:44.925724	\N	t	\N	2025-08-26 14:45:44.925724	2025-09-04 16:59:57.613451	20
\.


--
-- Data for Name: system_events; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.system_events (id, event_type, device_id, title, description, event_data, severity, "timestamp") FROM stdin;
1	discovery	1	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon	{"power": {"name": "Power", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "On/Off", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-08-26 10:02:02.55262
2	disconnection	1	Événement disconnection	Appareil Lampe Salon hors ligne	\N	low	2025-08-26 10:04:09.313536
3	discovery	1	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon Principal	{"color": {"name": "Couleur", "type": "color", "unit": "", "max_value": null, "min_value": null, "value_type": "color", "description": "Couleur RGB", "last_updated": null, "current_value": null, "allowed_values": []}, "power": {"name": "Alimentation", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "État marche/arrêt", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "Luminosité", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Niveau de luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-08-26 14:32:16.615715
4	discovery	1	Appareil découvert	Nouvel appareil SmartBox: lamp cuisine	{"color": {"name": "Couleur", "type": "color", "unit": "", "max_value": null, "min_value": null, "value_type": "color", "description": "Couleur RGB", "last_updated": null, "current_value": null, "allowed_values": []}, "power": {"name": "Alimentation", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "État marche/arrêt", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "Luminosité", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Niveau de luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-08-26 14:33:41.560795
5	discovery	4	Appareil découvert	Nouvel appareil SmartBox: lamp cuisine	{"color": {"name": "Couleur", "type": "color", "unit": "", "max_value": null, "min_value": null, "value_type": "color", "description": "Couleur RGB", "last_updated": null, "current_value": null, "allowed_values": []}, "power": {"name": "Alimentation", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "État marche/arrêt", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "Luminosité", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Niveau de luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-08-26 14:34:38.681189
6	disconnection	1	Événement disconnection	Appareil lamp cuisine hors ligne	\N	low	2025-08-26 14:36:03.616038
7	disconnection	4	Événement disconnection	Appareil lamp cuisine hors ligne	\N	low	2025-08-26 14:37:03.677719
8	discovery	5	Appareil découvert	Nouvel appareil SmartBox: Thermomètre Cuisine	{"humidity": {"name": "Humidité", "type": "humidity", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "float", "description": "Humidité relative", "last_updated": null, "current_value": null, "allowed_values": []}, "temperature": {"name": "Température", "type": "temperature", "unit": "°C", "max_value": 60, "min_value": -20, "value_type": "float", "description": "Température ambiante", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-08-26 14:45:44.925724
9	disconnection	5	Événement disconnection	Appareil Thermomètre Cuisine hors ligne	\N	low	2025-08-26 14:48:04.13359
10	disconnection	1	Événement disconnection	Appareil lamp cuisine hors ligne	\N	low	2025-08-26 14:49:34.177086
11	discovery	4	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon	{"power": {"name": "power", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "Allumer/Éteindre la lampe", "last_updated": null, "current_value": null, "allowed_values": []}, "status": {"name": "status", "type": "status", "unit": "", "max_value": null, "min_value": null, "value_type": "string", "description": "Rapport de statut", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "brightness", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-09-03 08:31:02.455134
12	discovery	4	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon	{"power": {"name": "power", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "Allumer/Éteindre la lampe", "last_updated": null, "current_value": null, "allowed_values": []}, "status": {"name": "status", "type": "status", "unit": "", "max_value": null, "min_value": null, "value_type": "string", "description": "Rapport de statut", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "brightness", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-09-03 16:41:46.631544
13	disconnection	4	Événement disconnection	Appareil Lampe Salon hors ligne	\N	low	2025-09-03 16:43:47.698139
14	discovery	4	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon	{"power": {"name": "power", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "Allumer/Éteindre la lampe", "last_updated": null, "current_value": null, "allowed_values": []}, "status": {"name": "status", "type": "status", "unit": "", "max_value": null, "min_value": null, "value_type": "string", "description": "Rapport de statut", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "brightness", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-09-04 08:49:43.656759
15	disconnection	4	Événement disconnection	Appareil Lampe Salon hors ligne	\N	low	2025-09-04 08:52:06.13521
16	discovery	4	Appareil découvert	Nouvel appareil SmartBox: Lampe Salon	{"power": {"name": "power", "type": "power", "unit": "", "max_value": null, "min_value": null, "value_type": "boolean", "description": "Allumer/Éteindre la lampe", "last_updated": null, "current_value": null, "allowed_values": []}, "status": {"name": "status", "type": "status", "unit": "", "max_value": null, "min_value": null, "value_type": "string", "description": "Rapport de statut", "last_updated": null, "current_value": null, "allowed_values": []}, "brightness": {"name": "brightness", "type": "brightness", "unit": "%", "max_value": 100, "min_value": 0, "value_type": "integer", "description": "Luminosité", "last_updated": null, "current_value": null, "allowed_values": []}}	low	2025-09-04 15:49:52.575922
17	disconnection	4	Événement disconnection	Appareil Lampe Salon hors ligne	\N	low	2025-09-04 15:51:55.727256
\.


--
-- Data for Name: system_settings; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.system_settings (id, setting_key, setting_value, setting_type, description, is_user_configurable, updated_at) FROM stdin;
\.


--
-- Name: automation_scenarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.automation_scenarios_id_seq', 1, false);


--
-- Name: capability_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.capability_history_id_seq', 60, true);


--
-- Name: capability_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.capability_types_id_seq', 24, true);


--
-- Name: device_capabilities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.device_capabilities_id_seq', 18, true);


--
-- Name: device_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.device_commands_id_seq', 1, false);


--
-- Name: device_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.device_types_id_seq', 27, true);


--
-- Name: locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.locations_id_seq', 24, true);


--
-- Name: smartbox_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.smartbox_devices_id_seq', 9, true);


--
-- Name: system_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.system_events_id_seq', 17, true);


--
-- Name: system_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: admin
--

SELECT pg_catalog.setval('public.system_settings_id_seq', 9, true);


--
-- Name: automation_scenarios automation_scenarios_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.automation_scenarios
    ADD CONSTRAINT automation_scenarios_pkey PRIMARY KEY (id);


--
-- Name: capability_history capability_history_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_history
    ADD CONSTRAINT capability_history_pkey PRIMARY KEY (id);


--
-- Name: capability_types capability_types_capability_code_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_types
    ADD CONSTRAINT capability_types_capability_code_key UNIQUE (capability_code);


--
-- Name: capability_types capability_types_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_types
    ADD CONSTRAINT capability_types_pkey PRIMARY KEY (id);


--
-- Name: device_capabilities device_capabilities_device_id_capability_code_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_capabilities
    ADD CONSTRAINT device_capabilities_device_id_capability_code_key UNIQUE (device_id, capability_code);


--
-- Name: device_capabilities device_capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_capabilities
    ADD CONSTRAINT device_capabilities_pkey PRIMARY KEY (id);


--
-- Name: device_commands device_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_pkey PRIMARY KEY (id);


--
-- Name: device_types device_types_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_types
    ADD CONSTRAINT device_types_pkey PRIMARY KEY (id);


--
-- Name: device_types device_types_type_code_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_types
    ADD CONSTRAINT device_types_type_code_key UNIQUE (type_code);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: smartbox_devices smartbox_devices_device_id_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.smartbox_devices
    ADD CONSTRAINT smartbox_devices_device_id_key UNIQUE (device_id);


--
-- Name: smartbox_devices smartbox_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.smartbox_devices
    ADD CONSTRAINT smartbox_devices_pkey PRIMARY KEY (id);


--
-- Name: system_events system_events_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_events
    ADD CONSTRAINT system_events_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);


--
-- Name: system_settings system_settings_setting_key_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_settings
    ADD CONSTRAINT system_settings_setting_key_key UNIQUE (setting_key);


--
-- Name: idx_active; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_active ON public.automation_scenarios USING btree (is_active);


--
-- Name: idx_capabilities_visible; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_capabilities_visible ON public.device_capabilities USING btree (is_visible, display_order);


--
-- Name: idx_capability_code; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_capability_code ON public.device_capabilities USING btree (capability_code);


--
-- Name: idx_capability_timestamp; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_capability_timestamp ON public.capability_history USING btree (device_capability_id, "timestamp" DESC);


--
-- Name: idx_commands_pending; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_commands_pending ON public.device_commands USING btree (status, created_at) WHERE (status = 'pending'::public.command_status_enum);


--
-- Name: idx_created_at; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_created_at ON public.device_commands USING btree (created_at);


--
-- Name: idx_device_capabilities_type_id; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_device_capabilities_type_id ON public.device_capabilities USING btree (capability_type_id);


--
-- Name: idx_device_status; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_device_status ON public.device_commands USING btree (device_id, status);


--
-- Name: idx_device_timestamp; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_device_timestamp ON public.system_events USING btree (device_id, "timestamp" DESC);


--
-- Name: idx_device_type; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_device_type ON public.smartbox_devices USING btree (device_type_code);


--
-- Name: idx_devices_online_location; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_devices_online_location ON public.smartbox_devices USING btree (is_online, location_id);


--
-- Name: idx_event_type; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_event_type ON public.system_events USING btree (event_type);


--
-- Name: idx_events_recent; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_events_recent ON public.system_events USING btree ("timestamp" DESC, event_type);


--
-- Name: idx_history_recent; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_history_recent ON public.capability_history USING btree ("timestamp" DESC);


--
-- Name: idx_last_seen; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_last_seen ON public.smartbox_devices USING btree (last_seen);


--
-- Name: idx_last_updated; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_last_updated ON public.device_capabilities USING btree (last_updated);


--
-- Name: idx_location; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_location ON public.smartbox_devices USING btree (location_id);


--
-- Name: idx_online_status; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_online_status ON public.smartbox_devices USING btree (is_online);


--
-- Name: idx_severity_timestamp; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_severity_timestamp ON public.system_events USING btree (severity, "timestamp" DESC);


--
-- Name: idx_smartbox_devices_type_id; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_smartbox_devices_type_id ON public.smartbox_devices USING btree (device_type_id);


--
-- Name: idx_timestamp; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_timestamp ON public.capability_history USING btree ("timestamp");


--
-- Name: idx_trigger_type; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_trigger_type ON public.automation_scenarios USING btree (trigger_type);


--
-- Name: automation_scenarios update_automation_scenarios_updated_at; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_automation_scenarios_updated_at BEFORE UPDATE ON public.automation_scenarios FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: device_capabilities update_device_capabilities_updated_at; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_device_capabilities_updated_at BEFORE UPDATE ON public.device_capabilities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: smartbox_devices update_smartbox_devices_updated_at; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_smartbox_devices_updated_at BEFORE UPDATE ON public.smartbox_devices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: system_settings update_system_settings_updated_at; Type: TRIGGER; Schema: public; Owner: admin
--

CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON public.system_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: capability_history capability_history_device_capability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.capability_history
    ADD CONSTRAINT capability_history_device_capability_id_fkey FOREIGN KEY (device_capability_id) REFERENCES public.device_capabilities(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: device_capabilities device_capabilities_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_capabilities
    ADD CONSTRAINT device_capabilities_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.smartbox_devices(id) ON DELETE CASCADE;


--
-- Name: device_commands device_commands_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_commands
    ADD CONSTRAINT device_commands_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.smartbox_devices(id) ON DELETE CASCADE;


--
-- Name: device_capabilities fk_device_capabilities_capability_type; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.device_capabilities
    ADD CONSTRAINT fk_device_capabilities_capability_type FOREIGN KEY (capability_type_id) REFERENCES public.capability_types(id);


--
-- Name: smartbox_devices fk_smartbox_devices_device_type; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.smartbox_devices
    ADD CONSTRAINT fk_smartbox_devices_device_type FOREIGN KEY (device_type_id) REFERENCES public.device_types(id);


--
-- Name: smartbox_devices smartbox_devices_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.smartbox_devices
    ADD CONSTRAINT smartbox_devices_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;


--
-- Name: system_events system_events_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.system_events
    ADD CONSTRAINT system_events_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.smartbox_devices(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

