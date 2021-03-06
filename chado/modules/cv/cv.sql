-- $Id: cv.sql,v 1.37 2007-02-28 15:08:48 briano Exp $
-- ==========================================
-- Chado cv module
--
-- =================================================================
-- Dependencies:
--
-- :import dbxref from db
-- =================================================================

-- ================================================
-- TABLE: cv
-- ================================================
create table cv (
    cv_id bigserial not null,
    primary key (cv_id),
    name varchar(255) not null,
   definition text,
   constraint cv_c1 unique (name)
);

COMMENT ON TABLE cv IS 'A controlled vocabulary or ontology. A cv is
composed of cvterms (AKA terms, classes, types, universals - relations
and properties are also stored in cvterm) and the relationships
between them.';

COMMENT ON COLUMN cv.name IS 'The name of the ontology. This
corresponds to the obo-format -namespace-. cv names uniquely identify
the cv. In OBO file format, the cv.name is known as the namespace.';

COMMENT ON COLUMN cv.definition IS 'A text description of the criteria for
membership of this ontology.';

-- ================================================
-- TABLE: cvterm
-- ================================================
create table cvterm (
    cvterm_id bigserial not null,
    primary key (cvterm_id),
    cv_id bigint not null,
    foreign key (cv_id) references cv (cv_id) on delete cascade INITIALLY DEFERRED,
    name varchar(1024) not null,
    definition text,
    dbxref_id bigint not null,
    foreign key (dbxref_id) references dbxref (dbxref_id) on delete set null INITIALLY DEFERRED,
    is_obsolete int not null default 0,
    is_relationshiptype int not null default 0,
    constraint cvterm_c1 unique (name,cv_id,is_obsolete),
    constraint cvterm_c2 unique (dbxref_id)
);
create index cvterm_idx1 on cvterm (cv_id);
create index cvterm_idx2 on cvterm (name);
create index cvterm_idx3 on cvterm (dbxref_id);

COMMENT ON TABLE cvterm IS 'A term, class, universal or type within an
ontology or controlled vocabulary.  This table is also used for
relations and properties. cvterms constitute nodes in the graph
defined by the collection of cvterms and cvterm_relationships.';

COMMENT ON COLUMN cvterm.cv_id IS 'The cv or ontology or namespace to which
this cvterm belongs.';

COMMENT ON COLUMN cvterm.name IS 'A concise human-readable name or
label for the cvterm. Uniquely identifies a cvterm within a cv.';

COMMENT ON COLUMN cvterm.definition IS 'A human-readable text
definition.';

COMMENT ON COLUMN cvterm.dbxref_id IS 'Primary identifier dbxref - The
unique global OBO identifier for this cvterm.  Note that a cvterm may
have multiple secondary dbxrefs - see also table: cvterm_dbxref.';

COMMENT ON COLUMN cvterm.is_obsolete IS 'Boolean 0=false,1=true; see
GO documentation for details of obsoletion. Note that two terms with
different primary dbxrefs may exist if one is obsolete.';

COMMENT ON COLUMN cvterm.is_relationshiptype IS 'Boolean
0=false,1=true relations or relationship types (also known as Typedefs
in OBO format, or as properties or slots) form a cv/ontology in
themselves. We use this flag to indicate whether this cvterm is an
actual term/class/universal or a relation. Relations may be drawn from
the OBO Relations ontology, but are not exclusively drawn from there.';

COMMENT ON INDEX cvterm_c1 IS 'A name can mean different things in
different contexts; for example "chromosome" in SO and GO. A name
should be unique within an ontology or cv. A name may exist twice in a
cv, in both obsolete and non-obsolete forms - these will be for
different cvterms with different OBO identifiers; so GO documentation
for more details on obsoletion. Note that occasionally multiple
obsolete terms with the same name will exist in the same cv. If this
is a possibility for the ontology under consideration (e.g. GO) then the
ID should be appended to the name to ensure uniqueness.';

COMMENT ON INDEX cvterm_c2 IS 'The OBO identifier is globally unique.';

-- ================================================
-- TABLE: cvterm_relationship
-- ================================================
create table cvterm_relationship (
    cvterm_relationship_id bigserial not null,
    primary key (cvterm_relationship_id),
    type_id bigint not null,
    foreign key (type_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    subject_id bigint not null,
    foreign key (subject_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    object_id bigint not null,
    foreign key (object_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    constraint cvterm_relationship_c1 unique (subject_id,object_id,type_id)
);
create index cvterm_relationship_idx1 on cvterm_relationship (type_id);
create index cvterm_relationship_idx2 on cvterm_relationship (subject_id);
create index cvterm_relationship_idx3 on cvterm_relationship (object_id);

COMMENT ON TABLE cvterm_relationship IS 'A relationship linking two
cvterms. Each cvterm_relationship constitutes an edge in the graph
defined by the collection of cvterms and cvterm_relationships. The
meaning of the cvterm_relationship depends on the definition of the
cvterm R refered to by type_id. However, in general the definitions
are such that the statement "all SUBJs REL some OBJ" is true. The
cvterm_relationship statement is about the subject, not the
object. For example "insect wing part_of thorax".';

COMMENT ON COLUMN cvterm_relationship.subject_id IS 'The subject of
the subj-predicate-obj sentence. The cvterm_relationship is about the
subject. In a graph, this typically corresponds to the child node.';

COMMENT ON COLUMN cvterm_relationship.object_id IS 'The object of the
subj-predicate-obj sentence. The cvterm_relationship refers to the
object. In a graph, this typically corresponds to the parent node.';

COMMENT ON COLUMN cvterm_relationship.type_id IS 'The nature of the
relationship between subject and object. Note that relations are also
housed in the cvterm table, typically from the OBO relationship
ontology, although other relationship types are allowed.';

-- ================================================
-- TABLE: cvtermpath
-- ================================================
create table cvtermpath (
    cvtermpath_id bigserial not null,
    primary key (cvtermpath_id),
    type_id bigint,
    foreign key (type_id) references cvterm (cvterm_id) on delete set null INITIALLY DEFERRED,
    subject_id bigint not null,
    foreign key (subject_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    object_id bigint not null,
    foreign key (object_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    cv_id bigint not null,
    foreign key (cv_id) references cv (cv_id) on delete cascade INITIALLY DEFERRED,
    pathdistance int,
    constraint cvtermpath_c1 unique (subject_id,object_id,type_id,pathdistance)
);
create index cvtermpath_idx1 on cvtermpath (type_id);
create index cvtermpath_idx2 on cvtermpath (subject_id);
create index cvtermpath_idx3 on cvtermpath (object_id);
create index cvtermpath_idx4 on cvtermpath (cv_id);

COMMENT ON TABLE cvtermpath IS 'The reflexive transitive closure of
the cvterm_relationship relation.';

COMMENT ON COLUMN cvtermpath.type_id IS 'The relationship type that
this is a closure over. If null, then this is a closure over ALL
relationship types. If non-null, then this references a relationship
cvterm - note that the closure will apply to both this relationship
AND the OBO_REL:is_a (subclass) relationship.';

COMMENT ON COLUMN cvtermpath.cv_id IS 'Closures will mostly be within
one cv. If the closure of a relationship traverses a cv, then this
refers to the cv of the object_id cvterm.';

COMMENT ON COLUMN cvtermpath.pathdistance IS 'The number of steps
required to get from the subject cvterm to the object cvterm, counting
from zero (reflexive relationship).';

-- ================================================
-- TABLE: cvtermsynonym
-- ================================================
create table cvtermsynonym (
    cvtermsynonym_id bigserial not null,
    primary key (cvtermsynonym_id),
    cvterm_id bigint not null,
    foreign key (cvterm_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    synonym varchar(1024) not null,
    type_id bigint,
    foreign key (type_id) references cvterm (cvterm_id) on delete cascade  INITIALLY DEFERRED,
    constraint cvtermsynonym_c1 unique (cvterm_id,synonym)
);
create index cvtermsynonym_idx1 on cvtermsynonym (cvterm_id);

COMMENT ON TABLE cvtermsynonym IS 'A cvterm actually represents a
distinct class or concept. A concept can be refered to by different
phrases or names. In addition to the primary name (cvterm.name) there
can be a number of alternative aliases or synonyms. For example, "T
cell" as a synonym for "T lymphocyte".';

COMMENT ON COLUMN cvtermsynonym.type_id IS 'A synonym can be exact,
narrower, or broader than.';


-- ================================================
-- TABLE: cvterm_dbxref
-- ================================================
create table cvterm_dbxref (
    cvterm_dbxref_id bigserial not null,
    primary key (cvterm_dbxref_id),
    cvterm_id bigint not null,
    foreign key (cvterm_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
    dbxref_id bigint not null,
    foreign key (dbxref_id) references dbxref (dbxref_id) on delete cascade INITIALLY DEFERRED,
    is_for_definition int not null default 0,
    constraint cvterm_dbxref_c1 unique (cvterm_id,dbxref_id)
);
create index cvterm_dbxref_idx1 on cvterm_dbxref (cvterm_id);
create index cvterm_dbxref_idx2 on cvterm_dbxref (dbxref_id);

COMMENT ON TABLE cvterm_dbxref IS 'In addition to the primary
identifier (cvterm.dbxref_id) a cvterm can have zero or more secondary
identifiers/dbxrefs, which may refer to records in external
databases. The exact semantics of cvterm_dbxref are not fixed. For
example: the dbxref could be a pubmed ID that is pertinent to the
cvterm, or it could be an equivalent or similar term in another
ontology. For example, GO cvterms are typically linked to InterPro
IDs, even though the nature of the relationship between them is
largely one of statistical association. The dbxref may be have data
records attached in the same database instance, or it could be a
"hanging" dbxref pointing to some external database. NOTE: If the
desired objective is to link two cvterms together, and the nature of
the relation is known and holds for all instances of the subject
cvterm then consider instead using cvterm_relationship together with a
well-defined relation.';

COMMENT ON COLUMN cvterm_dbxref.is_for_definition IS 'A
cvterm.definition should be supported by one or more references. If
this column is true, the dbxref is not for a term in an external database -
it is a dbxref for provenance information for the definition.';


-- ================================================
-- TABLE: cvtermprop
-- ================================================
create table cvtermprop ( 
    cvtermprop_id bigserial not null, 
    primary key (cvtermprop_id), 
    cvterm_id bigint not null, 
    foreign key (cvterm_id) references cvterm (cvterm_id) on delete cascade, 
    type_id bigint not null, 
    foreign key (type_id) references cvterm (cvterm_id) on delete cascade, 
    value text not null default '', 
    rank int not null default 0,

    unique(cvterm_id, type_id, value, rank) 
);
create index cvtermprop_idx1 on cvtermprop (cvterm_id);
create index cvtermprop_idx2 on cvtermprop (type_id);

COMMENT ON TABLE cvtermprop IS 'Additional extensible properties can be attached to a cvterm using this table. Corresponds to -AnnotationProperty- in W3C OWL format.';

COMMENT ON COLUMN cvtermprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';

COMMENT ON COLUMN cvtermprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';

COMMENT ON COLUMN cvtermprop.rank IS 'Property-Value ordering. Any
cvterm can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


-- ================================================
-- TABLE: dbxrefprop
-- ================================================
create table dbxrefprop (
    dbxrefprop_id bigserial not null,
    primary key (dbxrefprop_id),
    dbxref_id bigint not null,
    foreign key (dbxref_id) references dbxref (dbxref_id) INITIALLY DEFERRED,
    type_id bigint not null,
    foreign key (type_id) references cvterm (cvterm_id) INITIALLY DEFERRED,
    value text not null default '',
    rank int not null default 0,
    constraint dbxrefprop_c1 unique (dbxref_id,type_id,rank)
);
create index dbxrefprop_idx1 on dbxrefprop (dbxref_id);
create index dbxrefprop_idx2 on dbxrefprop (type_id);

COMMENT ON TABLE dbxrefprop IS 'Metadata about a dbxref. Note that this is not defined in the dbxref module, as it depends on the cvterm table. This table has a structure analagous to cvtermprop.';


-- ================================================
-- TABLE: cvprop
-- ================================================
create table cvprop (
    cvprop_id bigserial not null,
    primary key (cvprop_id),
    cv_id bigint not null,
    foreign key (cv_id) references cv (cv_id) INITIALLY DEFERRED,
    type_id bigint not null,
    foreign key (type_id) references cvterm (cvterm_id) INITIALLY DEFERRED,
    value text,
    rank int not null default 0,
    constraint cvprop_c1 unique (cv_id,type_id,rank)
);

COMMENT ON TABLE cvprop IS 'Additional extensible properties can be attached to a cv using this table.  A notable example would be the cv version';

COMMENT ON COLUMN cvprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';
COMMENT ON COLUMN cvprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';

COMMENT ON COLUMN cvprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';

-- ================================================
-- TABLE: chadoprop
-- ================================================
create table chadoprop (
    chadoprop_id bigserial not null,
    primary key (chadoprop_id),
    type_id bigint not null,
    foreign key (type_id) references cvterm (cvterm_id) INITIALLY DEFERRED,
    value text,
    rank int not null default 0,
    constraint chadoprop_c1 unique (type_id,rank)
);

COMMENT ON TABLE chadoprop IS 'This table is different from other prop tables in the database, as it is for storing information about the database itself, like schema version';

COMMENT ON COLUMN chadoprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';
COMMENT ON COLUMN chadoprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';

COMMENT ON COLUMN chadoprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


-- ================================================
-- TABLE: dbprop
-- ================================================

create table dbprop (
  dbprop_id bigserial not null,
  primary key (dbprop_id),
  db_id bigint not null,
  type_id bigint not null,
  value text null,
  rank int not null default 0,
  foreign key (type_id) references cvterm (cvterm_id) on delete cascade INITIALLY DEFERRED,
  foreign key (db_id) references db (db_id) on delete cascade INITIALLY DEFERRED,
  constraint dbprop_c1 unique (db_id,type_id,rank)
);
create index dbprop_idx1 on dbprop (db_id);
create index dbprop_idx2 on dbprop (type_id);

COMMENT ON TABLE dbprop IS 'An external database can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, dbprop_c1, for
the combination of db_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';

