import accessibleAutocomplete from "accessible-autocomplete";

export const request = endpoint => {
  let xhr = null; // Hoist this call so that we can abort previous requests.

  return (query, callback) => {
    if (xhr && xhr.readyState !== XMLHttpRequest.DONE) {
      xhr.abort();
    }
    const path = `${endpoint}?query=${query}`;

    xhr = new XMLHttpRequest();
    xhr.addEventListener("load", evt => {
      let results = [];
      try {
        results = JSON.parse(xhr.responseText);
      } catch (err) {
        console.error(
          `Failed to parse results from endpoint ${path}, error is:`,
          err
        );
      }
      callback(results);
    });
    xhr.open("GET", path);
    xhr.send();
  };
};

export const initAutocomplete = ($el, $input, inputValueTemplate) => {
  accessibleAutocomplete({
    element: $el,
    id: $input.id,
    showNoOptionsFound: true,
    name: $input.name,
    defaultValue: $input.value,
    minLength: 3,
    source: request("/providers/suggest"),
    templates: {
      inputValue: inputValueTemplate,
      suggestion: result => result && `${result.name} (${result.code})`
    },
    onConfirm: option => ($input.value = option ? option.code : ""),
    autoselect: true
  });

  // Hijack the original input to submit the selected provider_code.
  $input.id = `old-${$input.id}`;
  $input.name = "course[autocompleted_provider_code]";
  $input.type = "hidden";
};
