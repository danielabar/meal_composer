SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: daily_macro_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_macro_targets (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    carbs_grams numeric(8,2) DEFAULT 0.0 NOT NULL,
    protein_grams numeric(8,2) DEFAULT 0.0 NOT NULL,
    fat_grams numeric(8,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: daily_macro_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_macro_targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_macro_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_macro_targets_id_seq OWNED BY public.daily_macro_targets.id;


--
-- Name: daily_meal_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_meal_plans (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    daily_macro_target_id bigint NOT NULL,
    daily_meal_structure_id bigint NOT NULL,
    name character varying NOT NULL,
    target_carbs_grams numeric(8,2) NOT NULL,
    target_protein_grams numeric(8,2) NOT NULL,
    target_fat_grams numeric(8,2) NOT NULL,
    actual_carbs_grams numeric(8,2) NOT NULL,
    actual_protein_grams numeric(8,2) NOT NULL,
    actual_fat_grams numeric(8,2) NOT NULL,
    within_tolerance boolean DEFAULT false NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: daily_meal_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_meal_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_meal_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_meal_plans_id_seq OWNED BY public.daily_meal_plans.id;


--
-- Name: daily_meal_structures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_meal_structures (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: daily_meal_structures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_meal_structures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: daily_meal_structures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_meal_structures_id_seq OWNED BY public.daily_meal_structures.id;


--
-- Name: food_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.food_categories (
    id bigint NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: food_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.food_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: food_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.food_categories_id_seq OWNED BY public.food_categories.id;


--
-- Name: food_nutrients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.food_nutrients (
    id bigint NOT NULL,
    fdc_id integer NOT NULL,
    nutrient_id bigint NOT NULL,
    amount numeric(15,6),
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: food_nutrients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.food_nutrients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: food_nutrients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.food_nutrients_id_seq OWNED BY public.food_nutrients.id;


--
-- Name: food_portions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.food_portions (
    id bigint NOT NULL,
    meal_id bigint NOT NULL,
    food_id bigint NOT NULL,
    grams numeric(8,2) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: food_portions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.food_portions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: food_portions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.food_portions_id_seq OWNED BY public.food_portions.id;


--
-- Name: foods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.foods (
    id bigint NOT NULL,
    fdc_id integer NOT NULL,
    description text NOT NULL,
    food_category_id bigint NOT NULL,
    publication_date date NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: foods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.foods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: foods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.foods_id_seq OWNED BY public.foods.id;


--
-- Name: meal_structure_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meal_structure_items (
    id bigint NOT NULL,
    daily_meal_structure_id bigint NOT NULL,
    meal_label character varying NOT NULL,
    food_category_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    "position" integer DEFAULT 0,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: meal_structure_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meal_structure_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meal_structure_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meal_structure_items_id_seq OWNED BY public.meal_structure_items.id;


--
-- Name: meals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meals (
    id bigint NOT NULL,
    daily_meal_plan_id bigint NOT NULL,
    meal_type character varying NOT NULL,
    actual_carbs_grams numeric(8,2) NOT NULL,
    actual_protein_grams numeric(8,2) NOT NULL,
    actual_fat_grams numeric(8,2) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: meals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meals_id_seq OWNED BY public.meals.id;


--
-- Name: nutrients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nutrients (
    id bigint NOT NULL,
    name text NOT NULL,
    unit_name text NOT NULL,
    rank numeric(10,1) NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    nutrient_nbr character varying
);


--
-- Name: nutrients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nutrients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nutrients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nutrients_id_seq OWNED BY public.nutrients.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: daily_macro_targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_macro_targets ALTER COLUMN id SET DEFAULT nextval('public.daily_macro_targets_id_seq'::regclass);


--
-- Name: daily_meal_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_plans ALTER COLUMN id SET DEFAULT nextval('public.daily_meal_plans_id_seq'::regclass);


--
-- Name: daily_meal_structures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_structures ALTER COLUMN id SET DEFAULT nextval('public.daily_meal_structures_id_seq'::regclass);


--
-- Name: food_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_categories ALTER COLUMN id SET DEFAULT nextval('public.food_categories_id_seq'::regclass);


--
-- Name: food_nutrients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_nutrients ALTER COLUMN id SET DEFAULT nextval('public.food_nutrients_id_seq'::regclass);


--
-- Name: food_portions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_portions ALTER COLUMN id SET DEFAULT nextval('public.food_portions_id_seq'::regclass);


--
-- Name: foods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.foods ALTER COLUMN id SET DEFAULT nextval('public.foods_id_seq'::regclass);


--
-- Name: meal_structure_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meal_structure_items ALTER COLUMN id SET DEFAULT nextval('public.meal_structure_items_id_seq'::regclass);


--
-- Name: meals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meals ALTER COLUMN id SET DEFAULT nextval('public.meals_id_seq'::regclass);


--
-- Name: nutrients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrients ALTER COLUMN id SET DEFAULT nextval('public.nutrients_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: daily_macro_targets daily_macro_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_macro_targets
    ADD CONSTRAINT daily_macro_targets_pkey PRIMARY KEY (id);


--
-- Name: daily_meal_plans daily_meal_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_plans
    ADD CONSTRAINT daily_meal_plans_pkey PRIMARY KEY (id);


--
-- Name: daily_meal_structures daily_meal_structures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_structures
    ADD CONSTRAINT daily_meal_structures_pkey PRIMARY KEY (id);


--
-- Name: food_categories food_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_categories
    ADD CONSTRAINT food_categories_pkey PRIMARY KEY (id);


--
-- Name: food_nutrients food_nutrients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_nutrients
    ADD CONSTRAINT food_nutrients_pkey PRIMARY KEY (id);


--
-- Name: food_portions food_portions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_portions
    ADD CONSTRAINT food_portions_pkey PRIMARY KEY (id);


--
-- Name: foods foods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.foods
    ADD CONSTRAINT foods_pkey PRIMARY KEY (id);


--
-- Name: meal_structure_items meal_structure_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meal_structure_items
    ADD CONSTRAINT meal_structure_items_pkey PRIMARY KEY (id);


--
-- Name: meals meals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meals
    ADD CONSTRAINT meals_pkey PRIMARY KEY (id);


--
-- Name: nutrients nutrients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nutrients
    ADD CONSTRAINT nutrients_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_daily_macro_targets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_macro_targets_on_user_id ON public.daily_macro_targets USING btree (user_id);


--
-- Name: index_daily_macro_targets_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_daily_macro_targets_on_user_id_and_name ON public.daily_macro_targets USING btree (user_id, name);


--
-- Name: index_daily_meal_plans_on_daily_macro_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_meal_plans_on_daily_macro_target_id ON public.daily_meal_plans USING btree (daily_macro_target_id);


--
-- Name: index_daily_meal_plans_on_daily_meal_structure_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_meal_plans_on_daily_meal_structure_id ON public.daily_meal_plans USING btree (daily_meal_structure_id);


--
-- Name: index_daily_meal_plans_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_meal_plans_on_user_id ON public.daily_meal_plans USING btree (user_id);


--
-- Name: index_daily_meal_plans_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_daily_meal_plans_on_user_id_and_name ON public.daily_meal_plans USING btree (user_id, name);


--
-- Name: index_daily_meal_structures_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_daily_meal_structures_on_user_id ON public.daily_meal_structures USING btree (user_id);


--
-- Name: index_daily_meal_structures_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_daily_meal_structures_on_user_id_and_name ON public.daily_meal_structures USING btree (user_id, name);


--
-- Name: index_food_categories_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_food_categories_on_code ON public.food_categories USING btree (code);


--
-- Name: index_food_nutrients_on_fdc_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_food_nutrients_on_fdc_id ON public.food_nutrients USING btree (fdc_id);


--
-- Name: index_food_nutrients_on_fdc_id_and_nutrient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_food_nutrients_on_fdc_id_and_nutrient_id ON public.food_nutrients USING btree (fdc_id, nutrient_id);


--
-- Name: index_food_nutrients_on_nutrient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_food_nutrients_on_nutrient_id ON public.food_nutrients USING btree (nutrient_id);


--
-- Name: index_food_portions_on_food_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_food_portions_on_food_id ON public.food_portions USING btree (food_id);


--
-- Name: index_food_portions_on_meal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_food_portions_on_meal_id ON public.food_portions USING btree (meal_id);


--
-- Name: index_foods_on_fdc_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_foods_on_fdc_id ON public.foods USING btree (fdc_id);


--
-- Name: index_foods_on_food_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_foods_on_food_category_id ON public.foods USING btree (food_category_id);


--
-- Name: index_meal_structure_items_on_daily_meal_structure_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meal_structure_items_on_daily_meal_structure_id ON public.meal_structure_items USING btree (daily_meal_structure_id);


--
-- Name: index_meal_structure_items_on_food_category_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meal_structure_items_on_food_category_ids ON public.meal_structure_items USING gin (food_category_ids);


--
-- Name: index_meals_on_daily_meal_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meals_on_daily_meal_plan_id ON public.meals USING btree (daily_meal_plan_id);


--
-- Name: index_meals_on_daily_meal_plan_id_and_meal_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meals_on_daily_meal_plan_id_and_meal_type ON public.meals USING btree (daily_meal_plan_id, meal_type);


--
-- Name: index_nutrients_on_name_and_unit_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_nutrients_on_name_and_unit_name ON public.nutrients USING btree (name, unit_name);


--
-- Name: index_nutrients_on_nutrient_nbr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nutrients_on_nutrient_nbr ON public.nutrients USING btree (nutrient_nbr);


--
-- Name: index_nutrients_on_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_nutrients_on_rank ON public.nutrients USING btree (rank);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: meals fk_rails_0381c7b5fa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meals
    ADD CONSTRAINT fk_rails_0381c7b5fa FOREIGN KEY (daily_meal_plan_id) REFERENCES public.daily_meal_plans(id);


--
-- Name: food_nutrients fk_rails_09286a8cac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_nutrients
    ADD CONSTRAINT fk_rails_09286a8cac FOREIGN KEY (fdc_id) REFERENCES public.foods(fdc_id);


--
-- Name: daily_meal_structures fk_rails_17de8fbaad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_structures
    ADD CONSTRAINT fk_rails_17de8fbaad FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: food_portions fk_rails_32d8fab94e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_portions
    ADD CONSTRAINT fk_rails_32d8fab94e FOREIGN KEY (meal_id) REFERENCES public.meals(id);


--
-- Name: daily_macro_targets fk_rails_612f14eaf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_macro_targets
    ADD CONSTRAINT fk_rails_612f14eaf4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: daily_meal_plans fk_rails_6394a62f50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_plans
    ADD CONSTRAINT fk_rails_6394a62f50 FOREIGN KEY (daily_macro_target_id) REFERENCES public.daily_macro_targets(id);


--
-- Name: daily_meal_plans fk_rails_714addb488; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_plans
    ADD CONSTRAINT fk_rails_714addb488 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: daily_meal_plans fk_rails_747578593c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_meal_plans
    ADD CONSTRAINT fk_rails_747578593c FOREIGN KEY (daily_meal_structure_id) REFERENCES public.daily_meal_structures(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: meal_structure_items fk_rails_7d1c1c201d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meal_structure_items
    ADD CONSTRAINT fk_rails_7d1c1c201d FOREIGN KEY (daily_meal_structure_id) REFERENCES public.daily_meal_structures(id);


--
-- Name: foods fk_rails_a28abb337f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.foods
    ADD CONSTRAINT fk_rails_a28abb337f FOREIGN KEY (food_category_id) REFERENCES public.food_categories(id);


--
-- Name: food_nutrients fk_rails_acb42752f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_nutrients
    ADD CONSTRAINT fk_rails_acb42752f5 FOREIGN KEY (nutrient_id) REFERENCES public.nutrients(id);


--
-- Name: food_portions fk_rails_cc7784b4ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.food_portions
    ADD CONSTRAINT fk_rails_cc7784b4ab FOREIGN KEY (food_id) REFERENCES public.foods(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251014223321'),
('20251014223247'),
('20251014223212'),
('20251014133702'),
('20251013001011'),
('20251012233902'),
('20251012212052'),
('20251012212051'),
('20251012140749'),
('20250928180036'),
('20250928172929'),
('20250928152141'),
('20250928145643');

