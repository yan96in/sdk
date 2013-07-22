// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of vmservice;

class Server {
  int port;
  static ContentType jsonContentType = ContentType.parse('application/json');
  final VmService service;
  HttpServer _server;

  Server(this.service, this.port);

  void _requestHandler(HttpRequest request) {
    // Allow cross origin requests.
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    final String path =
          request.uri.path == '/' ? '/index.html' : request.uri.path;

    var resource = Resource.resources[path];
    if (resource != null) {
      // Serving up a static resource (e.g. .css, .html, .png).
      request.response.headers.contentType = ContentType.parse(mimeType);
      request.response.add(resource.data);
      request.response.close();
      return;
    }

    var serviceRequest = new ServiceRequest();
    var r = serviceRequest.parse(request.uri);
    if (!r) {
      // Did not understand the request uri.
      serviceRequest.setErrorResponse('Invalid request uri: ${request.uri}');
    } else {
      r = service.runningIsolates.route(serviceRequest);
      if (!r) {
        // Nothing responds to this type of request.
        serviceRequest.setErrorResponse('No route for: $path');
      }
    }

    // Send response back over HTTP.
    request.response.headers.contentType = jsonContentType;
    request.response.write(serviceRequest.response);
    request.response.close();
  }

  Future startServer() {
    return HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port).then((s) {
      // Only display message when port is automatically selected.
      var display_message = (port == 0);
      // Retrieve port.
      port = s.port;
      _server = s;
      _server.listen(_requestHandler);
      if (display_message) {
        print('VmService listening on port $port');
      }
      return s;
    });
  }
}

