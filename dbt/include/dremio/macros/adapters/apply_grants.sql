/*Copyright (C) 2022 Dremio Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.*/

{%- macro dremio__support_multiple_grantees_per_dcl_statement() -%}
    {{ return(False) }}
{%- endmacro -%}

{%- macro dremio__split_grantee(grantee) -%}
    {%- set splitted = grantee.split(':') -%}

    {%- if splitted | length < 2 -%}
        {{ log("Deprecation warning: grants to users will soon require the user: prefix", info=True) }}
        {{ return(("user", grantee)) }}
    {%- else -%}
        {%- set prefix = splitted[0] -%}
        {%- set remainder = splitted[1:] | join(':') -%}

        {%- if prefix not in ['user', 'role'] -%}
            {% do exceptions.CompilationError("Invalid prefix. Use either user or role") %}
        {%- endif -%}

        {{ return((prefix, remainder)) }}
    {%- endif -%}
{%- endmacro -%}

{% macro dremio__get_show_grant_sql(relation) %}
    {%- if relation.type == 'table' -%}
        {%- set relation_without_double_quotes = target.datalake ~ '.' ~ target.root_path ~ '.' ~ relation.identifier-%}
    {%- else -%}
        {%- set relation_without_double_quotes = relation.database ~ '.' ~ relation.schema ~ '.' ~ relation.identifier-%}
    {%- endif %}

    {%- if target.cloud_host and not target.software_host -%}
        {%- set privileges_table = 'sys.project.privileges' -%}
    {%- elif target.software_host and not target.cloud_host -%}
        {%- set privileges_table = 'sys.privileges' -%}
    {%- else -%}
         {% do exceptions.CompilationError("Invalid profile configuration: please only specify one of cloud_host or software_host in profiles.yml") %}
    {%- endif %}
    SELECT privilege, grantee_type, grantee_id
        FROM {{privileges_table}}
        WHERE object_id='{{ relation_without_double_quotes }}'
{% endmacro %}

{%- macro dremio__get_grant_sql(relation, privilege, grantees) -%}
    {%- set type, name = dremio__split_grantee(grantees[0]) %}

    grant {{ privilege }} on {{ relation.type }} {{ relation }}
    to {{ type }} {{ adapter.quote(name) }}
{%- endmacro -%}

{%- macro dremio__get_revoke_sql(relation, privilege, grantees) -%}
    {%- set type, name = dremio__split_grantee(grantees[0]) %}

    revoke {{ privilege }} on {{ relation.type }} {{ relation }}
    from {{ type }} {{ adapter.quote(name) }}
{%- endmacro -%}

{% macro dremio__call_dcl_statements(dcl_statement_list) %}
    {% for dcl_statement in dcl_statement_list %}
        {% call statement('grants') %}
            {{ dcl_statement }};
        {% endcall %}
    {% endfor %}
{% endmacro %}
