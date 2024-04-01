import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Types "types";

actor {

  func decode_body(response_body: Blob): Text {
    switch(Text.decodeUtf8(response_body)) {
      case (null) {
        return "No value returned";
      };

      case(?response) {
        return response;
      }
    }
  };

  func get_request(url: Text, method: Types.HttpMethod, headers: [Types.HttpHeader],body: ?[Nat8], transform: ?Types.TransformContext): Types.HttpRequestArgs {
    return {
      url;
      max_response_bytes = null;
      headers;
      body;
      method;
      transform;
    }
  };

  func set_transform(raw : Types.TransformArgs): Types.CanisterHttpResponsePayload {
    return {
      status = raw.response.status;
      body = raw.response.body;
      headers = [
          {
              name = "Content-Security-Policy";
              value = "default-src 'self'";
          },
          { name = "Referrer-Policy"; value = "strict-origin" },
          { name = "Permissions-Policy"; value = "geolocation=(self)" },
          {
              name = "Strict-Transport-Security";
              value = "max-age=63072000";
          },
          { name = "X-Frame-Options"; value = "DENY" },
          { name = "X-Content-Type-Options"; value = "nosniff" },
      ];
    };
  };

  func get_transform(): Types.TransformContext {
    return {
      function = transform;
      context = Blob.fromArray([]);
    };
  };

  func get_ic(): Types.IC {
    return actor ("aaaaa-aa");
  };

  func get_header(request_type: Types.HttpMethod): [Types.HttpHeader] {
    if (request_type == #post) {
      return [
        { name = "Host"; value = "jsonplaceholder.typicode.com:443" },
        { name = "User-Agent"; value = "http_post_sample" },
        { name= "Content-Type"; value = "application/json; charset=UTF-8" }
      ];
    };
    return [];
  };

  func get_response(url: Text, method: Types.HttpMethod, body: ?[Nat8]): async Types.HttpResponsePayload {
    let ic: Types.IC = get_ic();
    let transform_context: Types.TransformContext = get_transform();
    let header: [Types.HttpHeader] = get_header(method);
    let http_request: Types.HttpRequestArgs = get_request(url, method, header, body, ?transform_context);
    Cycles.add(21_000_000_000);
    let http_response: Types.HttpResponsePayload = await ic.http_request(http_request);
    return http_response;
  };

  func response_body(http_response: Types.HttpResponsePayload): async Text {
    switch(http_response.status) {
      case(200) {
        let response_body: Blob = Blob.fromArray(http_response.body);
        let body: Text = decode_body(response_body);
        return body
      };

      case(404) {
        Debug.trap("Bad request");
      };
      
      case(_) {
        Debug.trap("Too bad of a request");
      };

    };
  };

  public func get_response_body(url: Text): async Result.Result<Text, Text> {
    try {
      let method: Types.HttpMethod = #get;
      let http_response: Types.HttpResponsePayload = await get_response(url, method, ?[]);
      return #ok(await response_body(http_response));
    } catch e {
      return #err(Error.message(e));
    }
  };

  func create_post(title: Text, body: Text, userId: Nat): [Nat8] {
    let request_body_json: Text = "{ 
      \"title\" : \"" # title # "\", 
      \"body\" : \"" # body # "\", 
      \"userId\" : \"" # Nat.toText(userId) #"\" 
    }";
    let response_body_as_blob: Blob = Text.encodeUtf8(request_body_json);
    return Blob.toArray(response_body_as_blob);
  };

  type PostInput = {
    url: Text;
    title: Text;
    body: Text;
    userId: Nat;
  };

  public func post_method(post_input: PostInput): async Result.Result<Text, Text> {
    try {
      let method: Types.HttpMethod = #post;
      let request_body_as_nat8: [Nat8] = create_post(post_input.title, post_input.body, post_input.userId); // e.g [34, 34,12, 0]
      let response: Types.HttpResponsePayload = await get_response(post_input.url, method, ?request_body_as_nat8);
      return #ok(await response_body(response));
    } catch e {
      return #err(Error.message(e));
    }
  };

  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
    let transformed : Types.CanisterHttpResponsePayload = set_transform(raw);
    return transformed;
  };

}