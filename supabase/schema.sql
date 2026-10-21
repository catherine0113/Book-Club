-- Run once in the Supabase SQL editor. Tables and RPCs are server-only.
create table public.events (
 id uuid primary key default gen_random_uuid(), name text not null,
 event_date timestamptz not null, end_time text not null default '18:00',location text not null,
 registration_deadline timestamptz not null, capacity integer not null check(capacity>0),fee integer not null default 0,
 gift_enabled boolean not null default true,gift_min integer not null,gift_max integer not null,
 registration_status text not null default 'open' check(registration_status in ('open','closed')),
 matching_status text not null default 'not_started' check(matching_status in ('not_started','generated')),
 created_at timestamptz not null default now()
);
create table public.participants (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.events(id),
 name text not null,nickname text not null,email text not null,phone text not null,
 instagram text not null default '',line_id text not null default '',book_title text not null,book_author text not null default '',book_intro text not null default '' check(char_length(book_intro)<=300),
 reading_preferences jsonb not null default '[]',join_gift_exchange boolean not null default false,
 wish_1 text not null default '',wish_2 text not null default '',wish_3 text not null default '',interests text not null default '',dislikes text not null default '',
 edit_token text unique not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(event_id,email)
);
create table public.gift_matches (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.events(id),
 giver_id uuid not null references public.participants(id),receiver_id uuid not null references public.participants(id),
 created_at timestamptz not null default now(),notification_status text not null default 'pending' check(notification_status in ('pending','sent','failed')),
 notification_sent_at timestamptz,check(giver_id<>receiver_id),unique(event_id,giver_id),unique(event_id,receiver_id)
);
create table public.match_restrictions (
 id uuid primary key default gen_random_uuid(),event_id uuid not null references public.events(id),
 participant_a uuid not null references public.participants(id),participant_b uuid not null references public.participants(id),reason text
);
alter table public.events enable row level security;
alter table public.participants enable row level security;
alter table public.gift_matches enable row level security;
alter table public.match_restrictions enable row level security;
-- No browser policies: all data access goes through authenticated server routes.
create function public.register_participant(payload jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare e events; p participants;
begin
 select * into strict e from events where id=(payload->>'event_id')::uuid for update;
 if e.registration_status<>'open' or now()>e.registration_deadline or e.matching_status<>'not_started' then raise exception 'Registration is closed.';end if;
 if (select count(*) from participants where event_id=e.id)>=e.capacity then raise exception 'This gathering is full.';end if;
 insert into participants(event_id,name,nickname,email,phone,instagram,line_id,book_title,book_author,book_intro,reading_preferences,join_gift_exchange,wish_1,wish_2,wish_3,interests,dislikes,edit_token)
 select e.id,payload->>'name',payload->>'nickname',payload->>'email',payload->>'phone',payload->>'instagram',payload->>'line_id',payload->>'book_title',payload->>'book_author',payload->>'book_intro',payload->'reading_preferences',(payload->>'join_gift_exchange')::boolean,payload->>'wish_1',payload->>'wish_2',payload->>'wish_3',payload->>'interests',payload->>'dislikes',payload->>'edit_token' returning * into p;
 return to_jsonb(p);
exception when unique_violation then raise exception 'This email is already registered. Please use your original edit link.';
end;$$;
create function public.edit_participant(token text,payload jsonb) returns boolean language plpgsql security definer set search_path=public as $$
declare e events; p participants;
begin
 select * into strict p from participants where edit_token=token;
 select * into strict e from events where id=p.event_id for update;
 if e.matching_status<>'not_started' and (payload->>'join_gift_exchange')::boolean<>p.join_gift_exchange then raise exception 'Secret Wish matching has already started. Your participation can no longer be changed.';end if;
 update participants set name=payload->>'name',nickname=payload->>'nickname',email=payload->>'email',phone=payload->>'phone',instagram=payload->>'instagram',line_id=payload->>'line_id',book_title=payload->>'book_title',book_author=payload->>'book_author',book_intro=payload->>'book_intro',reading_preferences=payload->'reading_preferences',join_gift_exchange=(payload->>'join_gift_exchange')::boolean,wish_1=payload->>'wish_1',wish_2=payload->>'wish_2',wish_3=payload->>'wish_3',interests=payload->>'interests',dislikes=payload->>'dislikes',updated_at=now() where id=p.id;
 return true;
end;$$;
create function public.save_matches(target_event uuid,pairs jsonb) returns boolean language plpgsql security definer set search_path=public as $$
declare e events; n integer;
begin
 select * into strict e from events where id=target_event for update;
 if e.matching_status<>'not_started' then raise exception 'Matches have already been generated.';end if;
 select count(*) into n from participants where event_id=target_event and join_gift_exchange;
 if n<2 or jsonb_array_length(pairs)<>n then raise exception 'Participant list changed. Please reload.';end if;
 if exists(select 1 from participants where event_id=target_event and join_gift_exchange and trim(wish_1)='') then raise exception 'Please complete all wishlists.';end if;
 if exists(select 1 from jsonb_array_elements(pairs) pair where not exists(select 1 from participants where id=(pair->>'giver_id')::uuid and event_id=target_event and join_gift_exchange) or not exists(select 1 from participants where id=(pair->>'receiver_id')::uuid and event_id=target_event and join_gift_exchange)) then raise exception 'Invalid participant.';end if;
 if exists(select 1 from jsonb_array_elements(pairs) pair join match_restrictions r on r.event_id=target_event and ((r.participant_a=(pair->>'giver_id')::uuid and r.participant_b=(pair->>'receiver_id')::uuid) or (r.participant_b=(pair->>'giver_id')::uuid and r.participant_a=(pair->>'receiver_id')::uuid))) then raise exception 'Match restrictions changed. Please retry.';end if;
 insert into gift_matches(event_id,giver_id,receiver_id) select target_event,(x->>'giver_id')::uuid,(x->>'receiver_id')::uuid from jsonb_array_elements(pairs) x;
 update events set matching_status='generated',registration_status='closed' where id=target_event;
 return true;
end;$$;
revoke all on function public.register_participant(jsonb),public.edit_participant(text,jsonb),public.save_matches(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.register_participant(jsonb),public.edit_participant(text,jsonb),public.save_matches(uuid,jsonb) to service_role;
insert into public.events(name,event_date,location,registration_deadline,capacity,fee,gift_min,gift_max) values ('Books, Wishes & Serendipity','2026-12-19 14:00:00+08','Taipei · Venue to be announced','2026-12-10 23:59:59+08',50,0,1000,1500);
