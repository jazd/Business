namespace Core.Fake
{
    public class Command : ICommand
    {
        public Command() {
        }

        public string CommandText { get; set; }

        public IReader ExecuteReader() {
            return new Reader();
        }
    }
}
