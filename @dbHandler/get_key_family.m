function keys = get_key_family(obj, keyOrig)
%%GET_KEY_FAMILY 
%   This is for 
key_fam = strsplit(keyOrig, '&');
key_fam = key_fam{1};

keys = obj.db.keys;

fin = false;
i = 1;
while ~fin
    whole_key = keys{i};
    key_cell = strsplit(whole_key, '&');
    key_str = key_cell{1};
    if ~strcmp(key_str, key_fam) || ~contains(whole_key, '&')
        % the ~contains(... is for keys that hold aux data, like microphone
        keys = setdiff(keys, {whole_key}); % winnow down
        i = i - 1;
    end

    i = i + 1;
    if i > length(keys)
        fin = true;
    end
end
end