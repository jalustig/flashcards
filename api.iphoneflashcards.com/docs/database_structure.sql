create table api_log (
    api_access_id serial ,
    datestamp timestamp not null default now(),
    ip_address inet,
    controller varchar(250) not null default '',
    action varchar(250) not null default '',
    is_logged_in bool not null default false,
    username text not null default '',
    search_term text not null default '',
    primary key (api_access_id)
);