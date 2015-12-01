part of server.src.endpoints_v1;

class ServerPresenter extends Presenter {
  present() {}
}

class ServerPresenterFactory extends PresenterFactory {
  Presenter getPresenter(Message m) => new ServerPresenter();
}
