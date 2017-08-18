-- mustache template

-- Create connection entry within guacamole_db using vars from manage/guacamole/database.cf

INSERT INTO {{{create_guac_connection.connection_table}}} (connection_name, protocol, parent_id, max_coonections, max_connections_per_user)
VALUES ('{{{create_guac_connection.name}}}',
    '{{{create_guac_connection.protocol}}}', -- must be VNC, RDP, or SSH
    '{{{create_guac_connection.parent_group}}}', -- BEN, NEED TO FIND THIS FROM A JOIN
    '{{{create_guac_connection.max_connections}}}',
    '{{{create_guac_connection.max_connections_per_user}}}',
    );

-- Grant this user all system permissions
INSERT INTO guacamole_system_permission
SELECT user_id, permission
FROM (
          SELECT 'guacadmin'  AS username, 'CREATE_CONNECTION'       AS permission
    UNION SELECT 'guacadmin'  AS username, 'CREATE_CONNECTION_GROUP' AS permission
    UNION SELECT 'guacadmin'  AS username, 'CREATE_SHARING_PROFILE'  AS permission
    UNION SELECT 'guacadmin'  AS username, 'CREATE_USER'             AS permission
    UNION SELECT 'guacadmin'  AS username, 'ADMINISTER'              AS permission
) permissions
JOIN guacamole_user ON permissions.username = guacamole_user.username;

-- Grant admin permission to read/update/administer self
INSERT INTO guacamole_user_permission
SELECT guacamole_user.user_id, affected.user_id, permission
FROM (
          SELECT 'guacadmin' AS username, 'guacadmin' AS affected_username, 'READ'       AS permission
    UNION SELECT 'guacadmin' AS username, 'guacadmin' AS affected_username, 'UPDATE'     AS permission
    UNION SELECT 'guacadmin' AS username, 'guacadmin' AS affected_username, 'ADMINISTER' AS permission
) permissions
JOIN guacamole_user          ON permissions.username = guacamole_user.username
JOIN guacamole_user affected ON permissions.affected_username = affected.username;

