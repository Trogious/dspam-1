-- $Id: mysql_objects-4.1.sql,v 1.42 2009/12/17 22:55:07 sbajic Exp $

create table dspam_token_data (
  uid int unsigned not null,
  token bigint unsigned not null,
  spam_hits bigint unsigned not null,
  innocent_hits bigint unsigned not null,
  last_hit date not null
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci PACK_KEYS=1;

create unique index id_token_data_01 on dspam_token_data(uid,token);

create table dspam_signature_data (
  uid int unsigned not null,
  signature char(32) COLLATE latin1_general_ci not null,
  data longblob not null,
  length int unsigned not null,
  created_on date not null
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci max_rows=2500000 avg_row_length=8096;

create unique index id_signature_data_01 on dspam_signature_data(uid,signature);
create index id_signature_data_02 on dspam_signature_data(created_on);

create table dspam_stats (
  uid int unsigned primary key,
  spam_learned bigint unsigned not null,
  innocent_learned bigint unsigned not null,
  spam_misclassified bigint unsigned not null,
  innocent_misclassified bigint unsigned not null,
  spam_corpusfed bigint unsigned not null,
  innocent_corpusfed bigint unsigned not null,
  spam_classified bigint unsigned not null,
  innocent_classified bigint unsigned not null
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;

create table dspam_preferences (
  uid int unsigned not null,
  preference varchar(32) COLLATE latin1_general_ci not null,
  value varchar(64) COLLATE latin1_general_ci not null
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;

create unique index id_preferences_01 on dspam_preferences(uid, preference);
